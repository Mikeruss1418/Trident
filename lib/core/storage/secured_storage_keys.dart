class SecureStorageKeys {
  SecureStorageKeys._();

  /// ----[VAULT KEYS]-------
  static const salt = 'vault_salt';
  static const encryptedDEKBlob = 'vault_encrypted_dek_blob';
  static const passwordVerifierBlob = 'vault_password_verifier_blob';

  /// ----[BIOMETRIC KEYS]-------
  static const biometricEnabled = 'biometric_enabled';
  static const biometricEncryptedDEK = 'biometric_encrypted_dek';
  static const biometricUnlockKey = 'biometric_unlock_key';
}
