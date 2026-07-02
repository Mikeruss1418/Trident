class SecureStorageKeys {
  SecureStorageKeys._();

  /// ----[MASTER TOKEN]----
  static const masterToken = 'master_token';

  /// ----[VAULT KEYS]-------
  static const salt = 'vault_salt';
  static const encryptedDEKBlob = 'vault_encrypted_dek_blob';
  static const passwordVerifierBlob = 'vault_password_verifier_blob';
}
