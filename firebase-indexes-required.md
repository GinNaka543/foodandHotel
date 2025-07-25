# Firebase Indexes Required

The following composite indexes need to be created in Firebase Console:

## 1. Point Transactions Index

**Collection:** `pointTransactions`
**Fields:**
- `userId` (Ascending)
- `createdAt` (Descending)

**How to create:**
1. Go to Firebase Console: https://console.firebase.google.com/
2. Select your project (ani-reco)
3. Navigate to Firestore Database
4. Click on "Indexes" tab
5. Click "Create Index"
6. Set:
   - Collection ID: `pointTransactions`
   - Fields:
     - Field: `userId`, Order: Ascending
     - Field: `createdAt`, Order: Descending
   - Query scope: Collection
7. Click "Create"

## 2. Visit Plans Index (if needed)

**Collection:** `visitPlans`
**Fields:**
- `userId` (Ascending)
- `createdAt` (Descending)

Follow the same steps as above but for the `visitPlans` collection.

## Alternative: Auto-create from error

When you run the app and get an index error, Firebase will provide a direct link in the error message to create the required index. Simply:
1. Run the app
2. Check Xcode console for the error message
3. Click on the provided link
4. Confirm index creation in Firebase Console