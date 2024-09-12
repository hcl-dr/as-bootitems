# Overview

Firmware bundle build with Barebox, ATF, IMX Firmware and OPTEE (optional).
The bundle is packaged as a Rauc archive for simple install.

## Build

    $ make clean; make

## Build with OPTEE

    The IMX Code Signing Tool (cst) must be installed and at version >= 3.3.2.

    $ make clean; make OTPEE=1

## Signing (Secure Boot)

If not using a HSM (pkcs11), the signing keys passphrase may be decrypted using

Uses cst/keys/key_pass.txt (Must be encrypted at rest)
After build is completed, remember to delete the _key_pass.txt_ file.

## Signing of Rauc bundle

Certificate and key gathered from environment, example using PKCS11:

    $ export RAUC_KEY_FILE="pkcs11:token=XXXX;object=rauc-prod"
    $ export RAUC_CERT_FILE=XXX.pem

### Secrets and variables (prod) environment

| ID   | Type (S/V) | Comment    |
| :--- | :--------: | :--------- |
| CST_KEY | S | CST passphrase, repeated twice in _key_pass.txt_ |
| RAUC_KEY | S | OpenSSL signing key |
| RAUC_CERT | V | OpenSSL signing certificate |
| REPO_TOKEN | S | Fine grained PAS covering subrepos |
