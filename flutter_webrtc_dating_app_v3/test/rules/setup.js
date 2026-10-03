// Shared emulator setup. Run via `npm run test:emulators` (starts the
// Firestore, RTDB and Storage emulators from ../../firebase.json).
const fs = require('fs');
const path = require('path');
const { initializeTestEnvironment } = require('@firebase/rules-unit-testing');

const appRoot = path.resolve(__dirname, '..', '..');
const read = (f) => fs.readFileSync(path.join(appRoot, f), 'utf8');

async function createEnv() {
  return initializeTestEnvironment({
    projectId: 'demo-destined',
    firestore: { rules: read('firestore.rules') },
    database: { rules: read('database.rules.json') },
    storage: { rules: read('storage.rules') },
  });
}

module.exports = { createEnv };
