import 'dart:convert';

import 'package:bip39/bip39.dart' as bip39;
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InvalidMnemonicException implements Exception {
  const InvalidMnemonicException(
      [this.message = 'The provided mnemonic is invalid.']);

  final String message;

  @override
  String toString() => message;
}

class UserIdentity {
  const UserIdentity({required this.mnemonic, required this.userId});

  final String mnemonic;
  final String userId;
}

class UserIdentityService {
  UserIdentityService._();

  static final UserIdentityService instance = UserIdentityService._();

  static const String _mnemonicKey = 'user_mnemonic';
  static const String _userIdKey = 'user_id';

  Future<UserIdentity> getOrCreateIdentity() async {
    final mnemonic = await _getMnemonic();
    if (mnemonic != null) {
      final userId = await _getUserId();
      if (userId != null) {
        return UserIdentity(mnemonic: mnemonic, userId: userId);
      }

      final derivedUserId = _deriveUserId(mnemonic);
      await _persistIdentity(mnemonic: mnemonic, userId: derivedUserId);
      return UserIdentity(mnemonic: mnemonic, userId: derivedUserId);
    }

    final generatedMnemonic = bip39.generateMnemonic();
    final normalizedMnemonic = _normalizeMnemonic(generatedMnemonic);
    final userId = _deriveUserId(normalizedMnemonic);
    await _persistIdentity(mnemonic: normalizedMnemonic, userId: userId);
    return UserIdentity(mnemonic: normalizedMnemonic, userId: userId);
  }

  Future<UserIdentity> importMnemonic(String mnemonic) async {
    final normalized = _normalizeMnemonic(mnemonic);
    if (!bip39.validateMnemonic(normalized)) {
      throw const InvalidMnemonicException();
    }

    final userId = _deriveUserId(normalized);
    await _persistIdentity(mnemonic: normalized, userId: userId);
    return UserIdentity(mnemonic: normalized, userId: userId);
  }

  Future<UserIdentity?> currentIdentity() async {
    final mnemonic = await _getMnemonic();
    final userId = await _getUserId();
    if (mnemonic == null || userId == null) {
      return null;
    }

    return UserIdentity(mnemonic: mnemonic, userId: userId);
  }

  Future<String?> _getMnemonic() async {
    final prefs = await SharedPreferences.getInstance();
    final mnemonic = prefs.getString(_mnemonicKey);
    if (mnemonic == null) {
      return null;
    }

    return _normalizeMnemonic(mnemonic);
  }

  Future<String?> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  Future<void> _persistIdentity({
    required String mnemonic,
    required String userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mnemonicKey, mnemonic);
    await prefs.setString(_userIdKey, userId);
  }

  String _deriveUserId(String mnemonic) {
    final normalized = _normalizeMnemonic(mnemonic);
    final bytes = utf8.encode(normalized);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  String _normalizeMnemonic(String mnemonic) {
    final trimmed = mnemonic.trim();
    final words = trimmed.split(RegExp(r'\s+'));
    return words.map((word) => word.toLowerCase()).join(' ');
  }
}
