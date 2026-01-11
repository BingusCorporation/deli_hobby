const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// Auto-sync from users_private to users
exports.syncPublicUser = functions.firestore
  .document('users_private/{userId}')
  .onWrite(async (change, context) => {
    const userId = context.params.userId;
    
    if (!change.after.exists) {
      // If private user is deleted, delete public user
      await admin.firestore().collection('users').doc(userId).delete();
      return null;
    }
    
    const privateData = change.after.data();
    
    // Extract ALL public fields including email
    const publicData = {
      name: privateData.name || '',
      city: privateData.city || '',
      bio: privateData.bio || '',
      profilePic: privateData.profilePic || '',
      hobbies: privateData.hobbies || [],
      createdAt: privateData.createdAt || admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(), // Add update timestamp
    };
    
    // Update public user document
    await admin.firestore().collection('users').doc(userId).set(publicData, { merge: true });
    
    console.log(`Synced user ${userId} from private to public`);
    return null;
  });