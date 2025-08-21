const admin = require('firebase-admin');

// Initialize Firebase Admin with your service account
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert({
      "project_id": "kwaaijongens-app-88f1d",
      "private_key": "YOUR_PRIVATE_KEY_HERE",
      "client_email": "firebase-adminsdk-fbsvc@kwaaijongens-app-88f1d.iam.gserviceaccount.com"
    })
  });
}

module.exports = async (req, res) => {
  // Enable CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  
  const { token, title, body, data } = req.body;
  
  try {
    const message = {
      token: token,
      notification: {
        title: title || 'Kwaaijongens',
        body: body || 'Nieuw bericht!'
      },
      data: data || {}
    };
    
    const response = await admin.messaging().send(message);
    res.status(200).json({ success: true, messageId: response });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};