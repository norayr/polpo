MODULE TLS13Handshake;
IMPORT TLSBytes;

CONST
  HandshakeRecord* = 22;
  LegacyMajor = 3;
  LegacyMinor = 3;

  ClientHello* = 1;
  ServerHello* = 2;
  Finished* = 20;

  TLS13Major = 3;
  TLS13Minor = 4;

  CipherTLSAES128GCMSHA256Hi* = 19;  (* 0x13 *)
  CipherTLSAES128GCMSHA256Lo* = 1;   (* 0x01 *)

  ExtServerName = 0;
  ExtSupportedGroups = 10;
  ExtSignatureAlgorithms = 13;
  ExtSupportedVersions = 43;
  ExtKeyShare = 51;

  GroupX25519Hi = 0;
  GroupX25519Lo = 29;                (* 0x001d *)
  SigRsaPssRsaeSha256Hi = 8;
  SigRsaPssRsaeSha256Lo = 4;

PROCEDURE StringLen(s: ARRAY OF CHAR): LONGINT;
VAR i: LONGINT;
BEGIN
  i := 0;
  WHILE (i < LEN(s)) & (s[i] # 0X) DO INC(i) END;
  RETURN i
END StringLen;

PROCEDURE AppendHost(VAR b: TLSBytes.Buffer; host: ARRAY OF CHAR);
VAR i, n: LONGINT;
BEGIN
  n := StringLen(host); i := 0;
  WHILE i < n DO TLSBytes.AppendByte(b, ORD(host[i])); INC(i) END
END AppendHost;

PROCEDURE AppendExtension(VAR dst: TLSBytes.Buffer; extType: LONGINT; VAR data: TLSBytes.Buffer);
BEGIN
  TLSBytes.PutBE16(dst, extType);
  TLSBytes.PutBE16(dst, data.len);
  TLSBytes.Append(dst, data)
END AppendExtension;

PROCEDURE MakeSNI(host: ARRAY OF CHAR; VAR extData: TLSBytes.Buffer);
VAR n: LONGINT;
BEGIN
  n := StringLen(host);
  TLSBytes.Init(extData);
  TLSBytes.PutBE16(extData, 1 + 2 + n);  (* server_name_list length *)
  TLSBytes.AppendByte(extData, 0);       (* host_name *)
  TLSBytes.PutBE16(extData, n);
  AppendHost(extData, host)
END MakeSNI;

PROCEDURE MakeSupportedVersions(VAR extData: TLSBytes.Buffer);
BEGIN
  TLSBytes.Init(extData);
  TLSBytes.AppendByte(extData, 2);
  TLSBytes.AppendByte(extData, TLS13Major);
  TLSBytes.AppendByte(extData, TLS13Minor)
END MakeSupportedVersions;

PROCEDURE MakeSignatureAlgorithms(VAR extData: TLSBytes.Buffer);
BEGIN
  TLSBytes.Init(extData);
  (*
     Offer the common TLS 1.3 certificate signature schemes.
     The first live version offered only rsa_pss_rsae_sha256, which can make
     real servers with ECDSA certificates abort before ServerHello.
  *)
  TLSBytes.PutBE16(extData, 12);
  TLSBytes.AppendByte(extData, 4); TLSBytes.AppendByte(extData, 3);  (* ecdsa_secp256r1_sha256 *)
  TLSBytes.AppendByte(extData, 8); TLSBytes.AppendByte(extData, 4);  (* rsa_pss_rsae_sha256 *)
  TLSBytes.AppendByte(extData, 8); TLSBytes.AppendByte(extData, 5);  (* rsa_pss_rsae_sha384 *)
  TLSBytes.AppendByte(extData, 8); TLSBytes.AppendByte(extData, 6);  (* rsa_pss_rsae_sha512 *)
  TLSBytes.AppendByte(extData, 4); TLSBytes.AppendByte(extData, 1);  (* rsa_pkcs1_sha256 *)
  TLSBytes.AppendByte(extData, 5); TLSBytes.AppendByte(extData, 1)   (* rsa_pkcs1_sha384 *)
END MakeSignatureAlgorithms;

PROCEDURE MakeSupportedGroups(VAR extData: TLSBytes.Buffer);
BEGIN
  TLSBytes.Init(extData);
  TLSBytes.PutBE16(extData, 2);
  TLSBytes.AppendByte(extData, GroupX25519Hi);
  TLSBytes.AppendByte(extData, GroupX25519Lo)
END MakeSupportedGroups;

PROCEDURE MakeClientKeyShare(VAR pubKey: TLSBytes.Buffer; VAR extData: TLSBytes.Buffer);
BEGIN
  IF pubKey.len # 32 THEN HALT(90) END;
  TLSBytes.Init(extData);
  TLSBytes.PutBE16(extData, 2 + 2 + pubKey.len);  (* client_shares vector length *)
  TLSBytes.AppendByte(extData, GroupX25519Hi);
  TLSBytes.AppendByte(extData, GroupX25519Lo);
  TLSBytes.PutBE16(extData, pubKey.len);
  TLSBytes.Append(extData, pubKey)
END MakeClientKeyShare;

PROCEDURE BuildClientHelloMessage*(host: ARRAY OF CHAR; VAR random, pubKey: TLSBytes.Buffer; VAR msg: TLSBytes.Buffer);
VAR body, exts, e: TLSBytes.Buffer;
BEGIN
  IF random.len # 32 THEN HALT(91) END;
  IF pubKey.len # 32 THEN HALT(92) END;

  TLSBytes.Init(exts);
  MakeSNI(host, e); AppendExtension(exts, ExtServerName, e);
  MakeSupportedVersions(e); AppendExtension(exts, ExtSupportedVersions, e);
  MakeSignatureAlgorithms(e); AppendExtension(exts, ExtSignatureAlgorithms, e);
  MakeSupportedGroups(e); AppendExtension(exts, ExtSupportedGroups, e);
  MakeClientKeyShare(pubKey, e); AppendExtension(exts, ExtKeyShare, e);

  TLSBytes.Init(body);
  TLSBytes.AppendByte(body, LegacyMajor);
  TLSBytes.AppendByte(body, LegacyMinor);
  TLSBytes.Append(body, random);
  (*
     TLS 1.3 compatibility mode: many real servers expect a non-empty
     legacy_session_id and will echo it in ServerHello. It is not secret.
  *)
  TLSBytes.AppendByte(body, 32);        (* legacy_session_id length *)
  TLSBytes.Append(body, random);        (* reuse random bytes as opaque session id *)
  TLSBytes.PutBE16(body, 2);            (* cipher_suites length *)
  TLSBytes.AppendByte(body, CipherTLSAES128GCMSHA256Hi);
  TLSBytes.AppendByte(body, CipherTLSAES128GCMSHA256Lo);
  TLSBytes.AppendByte(body, 1);         (* compression_methods length *)
  TLSBytes.AppendByte(body, 0);         (* null compression *)
  TLSBytes.PutBE16(body, exts.len);
  TLSBytes.Append(body, exts);

  TLSBytes.Init(msg);
  TLSBytes.AppendByte(msg, ClientHello);
  TLSBytes.PutBE24(msg, body.len);
  TLSBytes.Append(msg, body)
END BuildClientHelloMessage;

PROCEDURE BuildPlainHandshakeRecord*(VAR handshakeMsg: TLSBytes.Buffer; VAR record: TLSBytes.Buffer);
BEGIN
  TLSBytes.Init(record);
  TLSBytes.AppendByte(record, HandshakeRecord);
  TLSBytes.AppendByte(record, LegacyMajor);
  TLSBytes.AppendByte(record, LegacyMinor);
  TLSBytes.PutBE16(record, handshakeMsg.len);
  TLSBytes.Append(record, handshakeMsg)
END BuildPlainHandshakeRecord;

PROCEDURE BuildClientHelloRecord*(host: ARRAY OF CHAR; VAR random, pubKey: TLSBytes.Buffer; VAR record: TLSBytes.Buffer);
VAR msg: TLSBytes.Buffer;
BEGIN
  BuildClientHelloMessage(host, random, pubKey, msg);
  BuildPlainHandshakeRecord(msg, record)
END BuildClientHelloRecord;

PROCEDURE ExtractServerHelloKeyShare*(VAR msg: TLSBytes.Buffer; VAR pubKey: TLSBytes.Buffer): BOOLEAN;
VAR bodyLen, pos, endPos, sidLen, extLen, extEnd, et, el, keyLen: LONGINT;
BEGIN
  TLSBytes.Init(pubKey);
  IF msg.len < 4 THEN RETURN FALSE END;
  IF ORD(msg.data[0]) # ServerHello THEN RETURN FALSE END;
  bodyLen := TLSBytes.GetBE24(msg, 1);
  IF bodyLen # msg.len - 4 THEN RETURN FALSE END;

  pos := 4;
  IF pos + 2 + 32 + 1 > msg.len THEN RETURN FALSE END;
  INC(pos, 2);                         (* legacy_version *)
  INC(pos, 32);                        (* random *)
  sidLen := ORD(msg.data[pos]); INC(pos);
  IF pos + sidLen + 2 + 1 + 2 > msg.len THEN RETURN FALSE END;
  INC(pos, sidLen);                    (* session_id_echo *)
  IF (ORD(msg.data[pos]) # CipherTLSAES128GCMSHA256Hi) OR (ORD(msg.data[pos+1]) # CipherTLSAES128GCMSHA256Lo) THEN RETURN FALSE END;
  INC(pos, 2);                         (* cipher suite *)
  IF ORD(msg.data[pos]) # 0 THEN RETURN FALSE END;
  INC(pos);                            (* compression method *)
  extLen := TLSBytes.GetBE16(msg, pos); INC(pos, 2);
  extEnd := pos + extLen;
  IF extEnd # msg.len THEN RETURN FALSE END;

  WHILE pos + 4 <= extEnd DO
    et := TLSBytes.GetBE16(msg, pos);
    el := TLSBytes.GetBE16(msg, pos + 2);
    INC(pos, 4);
    IF pos + el > extEnd THEN RETURN FALSE END;
    IF et = ExtKeyShare THEN
      IF el < 4 THEN RETURN FALSE END;
      IF (ORD(msg.data[pos]) # GroupX25519Hi) OR (ORD(msg.data[pos+1]) # GroupX25519Lo) THEN RETURN FALSE END;
      keyLen := TLSBytes.GetBE16(msg, pos + 2);
      IF keyLen # 32 THEN RETURN FALSE END;
      IF keyLen + 4 # el THEN RETURN FALSE END;
      TLSBytes.Slice(msg, pos + 4, keyLen, pubKey);
      RETURN TRUE
    END;
    INC(pos, el)
  END;
  RETURN FALSE
END ExtractServerHelloKeyShare;

PROCEDURE IsPlainHandshakeRecord*(VAR record: TLSBytes.Buffer): BOOLEAN;
BEGIN
  RETURN (record.len >= 5) & (ORD(record.data[0]) = HandshakeRecord) & (ORD(record.data[1]) = LegacyMajor) & (ORD(record.data[2]) = LegacyMinor)
END IsPlainHandshakeRecord;

PROCEDURE GetRecordPayload*(VAR record, payload: TLSBytes.Buffer): BOOLEAN;
VAR len: LONGINT;
BEGIN
  TLSBytes.Init(payload);
  IF ~IsPlainHandshakeRecord(record) THEN RETURN FALSE END;
  len := TLSBytes.GetBE16(record, 3);
  IF len # record.len - 5 THEN RETURN FALSE END;
  TLSBytes.Slice(record, 5, len, payload);
  RETURN TRUE
END GetRecordPayload;

END TLS13Handshake.
