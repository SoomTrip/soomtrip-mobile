const profileAssets = {
  'profile1': 'assets/images/profile1.jpeg',
  'profile2': 'assets/images/profile2.jpeg',
  'profile3': 'assets/images/profile3.jpeg',
  'profile4': 'assets/images/profile4.jpg',
  'profile5': 'assets/images/profile5.jpg',
};

String? profileAsset(String? value, String? signedUrl) {
  if (signedUrl != null && signedUrl.isNotEmpty) return null;
  return profileAssets[value];
}
