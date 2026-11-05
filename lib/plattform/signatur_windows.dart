// Authenticode-Prüfung einer Programmdatei, nur Windows: Ist die Signatur
// gültig, und hat Anthropic unterschrieben? Damit entscheidet die App, ob sie
// eine gefundene claude.exe startet und ihr den Zugangsschlüssel gibt
// (lib/einrichtung.dart, claudeFinden). Der Ort einer Datei sagt darüber
// nichts mehr, seit Claude Desktop seine Ablage ändert.
//
// Direkt über wintrust.dll und crypt32.dll (dart:ffi), weil package:win32
// WinVerifyTrust nicht anbindet und PowerShell auf Schulrechnern oft
// eingeschränkt ist. Synchron und ohne Flutter, damit es auch beim
// Deinstallieren (--claude-entfernen) läuft. Aufgerufen wird es nur unter
// Windows; auf anderen Plattformen werden die DLLs nie geladen.
//
// Ohne Online-Sperrprüfung (WTD_REVOKE_NONE, WTD_CACHE_ONLY_URL_RETRIEVAL):
// Sonst fragte Windows für die App Zertifizierungsstellen im Netz an, und
// außer Moodle und GitHub fragt die App niemanden (E19).

import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// Organisation im Zertifikat der Programme von Anthropic. Gemessen an der
/// claude.exe aus Claude Desktop und aus der VS-Code-Erweiterung:
/// `CN="Anthropic, PBC", O="Anthropic, PBC", …`.
const anthropicOrganisation = 'Anthropic, PBC';

final class _Guid extends Struct {
  @Uint32()
  external int data1;
  @Uint16()
  external int data2;
  @Uint16()
  external int data3;
  @Array(8)
  external Array<Uint8> data4;
}

final class _WintrustFileInfo extends Struct {
  @Uint32()
  external int cbStruct;
  external Pointer<Utf16> pcwszFilePath;
  external Pointer<Void> hFile;
  external Pointer<_Guid> pgKnownSubject;
}

final class _WintrustData extends Struct {
  @Uint32()
  external int cbStruct;
  external Pointer<Void> pPolicyCallbackData;
  external Pointer<Void> pSIPClientData;
  @Uint32()
  external int dwUIChoice;
  @Uint32()
  external int fdwRevocationChecks;
  @Uint32()
  external int dwUnionChoice;
  external Pointer<_WintrustFileInfo> pFile;
  @Uint32()
  external int dwStateAction;
  external Pointer<Void> hWVTStateData;
  external Pointer<Utf16> pwszURLReference;
  @Uint32()
  external int dwProvFlags;
  @Uint32()
  external int dwUIContext;
  external Pointer<Void> pSignatureSettings;
}

const _wtdUiNone = 2;
const _wtdRevokeNone = 0;
const _wtdChoiceFile = 1;
const _wtdStateactionVerify = 1;
const _wtdStateactionClose = 2;
const _wtdRevocationCheckNone = 0x10;
const _wtdCacheOnlyUrlRetrieval = 0x1000;
const _certNameAttrType = 3;

typedef _WinVerifyTrustC = Int32 Function(IntPtr, Pointer<_Guid>, Pointer<Void>);
typedef _WinVerifyTrustDart = int Function(int, Pointer<_Guid>, Pointer<Void>);
typedef _ProvDataC = Pointer<Void> Function(Pointer<Void>);
typedef _ProvSignerC = Pointer<Void> Function(Pointer<Void>, Uint32, Int32, Uint32);
typedef _ProvSignerDart = Pointer<Void> Function(Pointer<Void>, int, int, int);
typedef _CertNameC = Uint32 Function(Pointer<Void>, Uint32, Uint32, Pointer<Void>, Pointer<Utf16>, Uint32);
typedef _CertNameDart = int Function(Pointer<Void>, int, int, Pointer<Void>, Pointer<Utf16>, int);

/// Ob [exe] eine gültige Authenticode-Signatur von Anthropic trägt. Jeder
/// Fehler, auch eine fehlende DLL, zählt als „nein".
bool vonAnthropic(String exe) {
  try {
    return _organisation(exe) == anthropicOrganisation;
  } catch (_) {
    return false;
  }
}

/// Die Organisation (O) im Zertifikat des Unterzeichners, wenn die Signatur
/// gültig ist; sonst null.
String? _organisation(String exe) {
  final wintrust = DynamicLibrary.open('wintrust.dll');
  final crypt32 = DynamicLibrary.open('crypt32.dll');
  final winVerifyTrust = wintrust.lookupFunction<_WinVerifyTrustC, _WinVerifyTrustDart>('WinVerifyTrust');
  final provData = wintrust.lookupFunction<_ProvDataC, _ProvDataC>('WTHelperProvDataFromStateData');
  final provSigner = wintrust.lookupFunction<_ProvSignerC, _ProvSignerDart>('WTHelperGetProvSignerFromChain');
  final certName = crypt32.lookupFunction<_CertNameC, _CertNameDart>('CertGetNameStringW');

  return using((arena) {
    // WINTRUST_ACTION_GENERIC_VERIFY_V2 {00AAC56B-CD44-11d0-8CC2-00C04FC295EE}
    final aktion = arena<_Guid>()
      ..ref.data1 = 0x00AAC56B
      ..ref.data2 = 0xCD44
      ..ref.data3 = 0x11D0;
    const d4 = [0x8C, 0xC2, 0x00, 0xC0, 0x4F, 0xC2, 0x95, 0xEE];
    for (var i = 0; i < 8; i++) {
      aktion.ref.data4[i] = d4[i];
    }
    final datei = arena<_WintrustFileInfo>()
      ..ref.cbStruct = sizeOf<_WintrustFileInfo>()
      ..ref.pcwszFilePath = exe.toNativeUtf16(allocator: arena);
    final daten = arena<_WintrustData>()
      ..ref.cbStruct = sizeOf<_WintrustData>()
      ..ref.dwUIChoice = _wtdUiNone
      ..ref.fdwRevocationChecks = _wtdRevokeNone
      ..ref.dwUnionChoice = _wtdChoiceFile
      ..ref.pFile = datei
      ..ref.dwStateAction = _wtdStateactionVerify
      ..ref.dwProvFlags = _wtdRevocationCheckNone | _wtdCacheOnlyUrlRetrieval;

    // INVALID_HANDLE_VALUE: keine Oberfläche, niemand sitzt davor.
    final ergebnis = winVerifyTrust(-1, aktion, daten.cast());
    try {
      if (ergebnis != 0) return null;
      final prov = provData(daten.ref.hWVTStateData);
      if (prov == nullptr) return null;
      final signer = provSigner(prov, 0, 0, 0);
      if (signer == nullptr) return null;
      // CRYPT_PROVIDER_SGNR (64 Bit): cbStruct, sftVerifyAsOf (FILETIME),
      // csCertChain bei 12, pasCertChain bei 16. Das erste Element der
      // Kette ist der Unterzeichner; in CRYPT_PROVIDER_CERT steht pCert bei 8.
      final anzahl = (signer.cast<Uint8>() + 12).cast<Uint32>().value;
      final kette = (signer.cast<Uint8>() + 16).cast<Pointer<Uint8>>().value;
      if (anzahl == 0 || kette == nullptr) return null;
      final zertifikat = (kette + 8).cast<Pointer<Void>>().value;
      if (zertifikat == nullptr) return null;
      final oid = '2.5.4.10'.toNativeUtf8(allocator: arena); // Organisation (O)
      const laenge = 256;
      final puffer = arena<Uint16>(laenge).cast<Utf16>();
      final n = certName(zertifikat, _certNameAttrType, 0, oid.cast(), puffer, laenge);
      return n <= 1 ? null : puffer.toDartString();
    } finally {
      daten.ref.dwStateAction = _wtdStateactionClose;
      winVerifyTrust(-1, aktion, daten.cast());
    }
  });
}
