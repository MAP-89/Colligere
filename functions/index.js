/*
 * Cloud Functions for Colligere.
 *
 * pushToCollaborativeProject — callable function that accepts an individual
 * user's contributions and merges them into a shared collaborative project.
 * Clients never write to /collaborativeProjects directly; this function is
 * the only path (enforced by Firestore Security Rules).
 *
 * See LinguaField_ClaudeCode_Spec.md sections 4.3 and 4.6.
 */

const {setGlobalOptions} = require("firebase-functions");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const {initializeApp} = require("firebase-admin/app");
const {
  getFirestore,
  Timestamp,
  FieldValue,
} = require("firebase-admin/firestore");
const {GoogleAuth} = require("google-auth-library");

setGlobalOptions({maxInstances: 10});

initializeApp();
const db = getFirestore();

const PROJECT_ID = process.env.GCLOUD_PROJECT || "colligere-502b6";
const VERTEX_LOCATION = "us-central1";
const EMBEDDING_MODEL = "text-embedding-005";
const EMBEDDING_DIMENSIONS = 768;
const MAX_PAIRS_PER_EMBEDDING = 500;

let cachedGoogleAuth = null;
/**
 * Lazy-initialised GoogleAuth client scoped for Vertex AI access.
 * @return {GoogleAuth} A cached, scoped auth instance.
 */
function getGoogleAuth() {
  if (!cachedGoogleAuth) {
    cachedGoogleAuth = new GoogleAuth({
      scopes: ["https://www.googleapis.com/auth/cloud-platform"],
    });
  }
  return cachedGoogleAuth;
}

/**
 * Normalises a phonetic string for consensus comparison. Strips surrounding
 * whitespace and lower-cases — but otherwise preserves IPA characters as-is.
 * @param {string} value Phonetic string from a contribution.
 * @return {string} Normalised key suitable for grouping near-identical entries.
 */
function normalisePhonetic(value) {
  return (value || "").trim().toLowerCase();
}

/*
 * pushToCollaborativeProject
 *
 * Payload:
 *   {
 *     collabProjectID: string,           // doc ID under /collaborativeProjects
 *     entries: [
 *       {
 *         seedItemID: string,            // ties contributions across users
 *         english: string,
 *         phonetic: string,              // required, non-empty
 *         notes?: string,
 *         isPrivate?: boolean,           // dropped server-side if true
 *         isUncertain?: boolean,         // dropped server-side if true
 *         audioStoragePath?: string|null // path in Firebase Storage
 *       }
 *     ]
 *   }
 *
 * Returns:
 *   { ok, entriesWritten, newContributor, consensusUpdates }
 */
exports.pushToCollaborativeProject = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in is required.");
  }
  const uid = request.auth.uid;
  const data = request.data || {};

  const collabProjectID = data.collabProjectID;
  const entries = data.entries;

  if (typeof collabProjectID !== "string" || collabProjectID.length === 0) {
    throw new HttpsError("invalid-argument", "collabProjectID is required.");
  }
  if (!Array.isArray(entries) || entries.length === 0) {
    throw new HttpsError(
        "invalid-argument",
        "entries[] is required and must be non-empty.",
    );
  }

  // Server-side filter: per spec 4.6, private + uncertain entries
  // never reach the collab project.
  const eligible = entries.filter((e) => {
    if (!e || typeof e !== "object") return false;
    if (typeof e.seedItemID !== "string" || e.seedItemID.length === 0) {
      return false;
    }
    if (typeof e.phonetic !== "string" || e.phonetic.trim().length === 0) {
      return false;
    }
    if (e.isPrivate === true) return false;
    if (e.isUncertain === true) return false;
    return true;
  });

  if (eligible.length === 0) {
    return {
      ok: true,
      entriesWritten: 0,
      newContributor: false,
      consensusUpdates: 0,
    };
  }

  const docRef = db.collection("collaborativeProjects").doc(collabProjectID);
  const now = Timestamp.now();

  let entriesWritten = 0;
  let newContributor = false;
  let consensusUpdates = 0;

  await db.runTransaction(async (tx) => {
    const snapshot = await tx.get(docRef);
    if (!snapshot.exists) {
      throw new HttpsError(
          "not-found",
          `Collaborative project ${collabProjectID} does not exist.`,
      );
    }

    const projectData = snapshot.data() || {};
    const lexicon = projectData.lexicon || {};
    const contributorUIDs = new Set(projectData.contributorUIDs || []);
    newContributor = !contributorUIDs.has(uid);

    for (const entry of eligible) {
      const slot = lexicon[entry.seedItemID] || {
        english: entry.english || "",
        contributions: [],
      };

      // A user's previous contribution for this seed is replaced,
      // not duplicated.
      slot.contributions = (slot.contributions || [])
          .filter((c) => c.uid !== uid);
      slot.contributions.push({
        uid,
        phonetic: entry.phonetic.trim(),
        notes: typeof entry.notes === "string" ? entry.notes : "",
        contributedAt: now,
        audioStoragePath: entry.audioStoragePath || null,
      });

      if (!slot.english && entry.english) {
        slot.english = entry.english;
      }

      // Consensus detection — ≥3 contributors agree on normalised phonetic.
      const tally = new Map();
      for (const c of slot.contributions) {
        const key = normalisePhonetic(c.phonetic);
        if (!key) continue;
        tally.set(key, (tally.get(key) || 0) + 1);
      }
      let consensusKey = null;
      let consensusCount = 0;
      for (const [key, count] of tally.entries()) {
        if (count > consensusCount) {
          consensusKey = key;
          consensusCount = count;
        }
      }
      if (consensusCount >= 3) {
        const canonical = slot.contributions
            .find((c) => normalisePhonetic(c.phonetic) === consensusKey);
        const consensusPhonetic =
            (canonical && canonical.phonetic) || consensusKey;
        if (slot.consensusPhonetic !== consensusPhonetic) {
          slot.consensusPhonetic = consensusPhonetic;
          consensusUpdates += 1;
        }
      }

      lexicon[entry.seedItemID] = slot;
      entriesWritten += 1;
    }

    contributorUIDs.add(uid);

    tx.set(docRef, {
      lexicon,
      contributorUIDs: Array.from(contributorUIDs),
      contributorCount: contributorUIDs.size,
      totalEntries: Object.keys(lexicon).length,
      lastUpdatedAt: now,
    }, {merge: true});
  });

  logger.info("pushToCollaborativeProject completed", {
    uid,
    collabProjectID,
    entriesWritten,
    newContributor,
    consensusUpdates,
  });

  return {ok: true, entriesWritten, newContributor, consensusUpdates};
});

/**
 * Calls Vertex AI text-embedding-005 to embed the given text into a
 * 768-dimensional vector. Uses ADC via google-auth-library.
 * @param {string} text The text to embed.
 * @return {Promise<number[]>} A vector of length EMBEDDING_DIMENSIONS.
 */
async function callVertexEmbedding(text) {
  const auth = getGoogleAuth();
  const client = await auth.getClient();
  const tokenResp = await client.getAccessToken();
  const token = tokenResp && tokenResp.token;
  if (!token) {
    throw new Error("Failed to obtain Vertex AI access token.");
  }

  const endpoint =
      `https://${VERTEX_LOCATION}-aiplatform.googleapis.com/v1` +
      `/projects/${PROJECT_ID}/locations/${VERTEX_LOCATION}` +
      `/publishers/google/models/${EMBEDDING_MODEL}:predict`;

  const resp = await fetch(endpoint, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      instances: [{content: text}],
    }),
  });

  if (!resp.ok) {
    const errBody = await resp.text();
    throw new Error(`Vertex AI error ${resp.status}: ${errBody}`);
  }

  const data = await resp.json();
  const values =
      data && data.predictions && data.predictions[0] &&
      data.predictions[0].embeddings && data.predictions[0].embeddings.values;
  if (!Array.isArray(values) || values.length !== EMBEDDING_DIMENSIONS) {
    throw new Error(
        `Unexpected Vertex AI response shape (got ${values && values.length}).`,
    );
  }
  return values;
}

/*
 * generateProjectEmbedding
 *
 * Payload:
 *   {
 *     projectID: string,            // /individualProjects doc ID
 *     entries: [{english: string, phonetic: string}]
 *   }
 *
 * Returns:
 *   { ok, pairCount, dimensions }
 *
 * Stores the vector at /individualProjects/{projectID}.lexiconEmbedding
 * along with lastEmbeddingUpdatedAt + embeddingPairCount.
 */
exports.generateProjectEmbedding = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in is required.");
  }
  const uid = request.auth.uid;
  const data = request.data || {};

  const projectID = data.projectID;
  const entries = data.entries;

  if (typeof projectID !== "string" || projectID.length === 0) {
    throw new HttpsError("invalid-argument", "projectID is required.");
  }
  if (!Array.isArray(entries) || entries.length === 0) {
    throw new HttpsError(
        "invalid-argument",
        "entries[] is required and must be non-empty.",
    );
  }

  const projectRef = db.collection("individualProjects").doc(projectID);
  const snapshot = await projectRef.get();
  if (!snapshot.exists) {
    throw new HttpsError(
        "not-found",
        `Project ${projectID} does not exist.`,
    );
  }
  const ownerUID = (snapshot.data() || {}).ownerUID;
  if (ownerUID !== uid) {
    throw new HttpsError(
        "permission-denied",
        "You can only generate embeddings for projects you own.",
    );
  }

  const pairs = entries
      .filter((e) => {
        if (!e || typeof e !== "object") return false;
        if (typeof e.english !== "string" || e.english.trim() === "") {
          return false;
        }
        if (typeof e.phonetic !== "string" || e.phonetic.trim() === "") {
          return false;
        }
        return true;
      })
      .map((e) => `${e.english.trim()}: ${e.phonetic.trim()}`);

  if (pairs.length === 0) {
    throw new HttpsError(
        "invalid-argument",
        "No usable [english]: [phonetic] pairs in entries.",
    );
  }

  const text = pairs.slice(0, MAX_PAIRS_PER_EMBEDDING).join("\n");
  const embedding = await callVertexEmbedding(text);

  await projectRef.set({
    lexiconEmbedding: FieldValue.vector(embedding),
    lastEmbeddingUpdatedAt: Timestamp.now(),
    embeddingPairCount: pairs.length,
  }, {merge: true});

  logger.info("generateProjectEmbedding completed", {
    uid,
    projectID,
    pairCount: pairs.length,
    dimensions: embedding.length,
  });

  return {
    ok: true,
    pairCount: pairs.length,
    dimensions: embedding.length,
  };
});
