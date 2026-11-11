# Local code signing

- Local source builds use **ad-hoc signing** by default. They need no paid Apple developer account.
- Ad-hoc signing checks code integrity. It does not give a stable certificate identity across rebuilds.
- macOS can require a new Accessibility approval after an ad-hoc rebuild.
- An optional local code-signing certificate can give successive builds the same certificate-based identity.
- A self-signed certificate is not an Apple Developer ID. It does not provide notarization or distribution trust on a friend's Mac.
- Do not share your private key or import another person's key to build this project.

## Use an existing local certificate

- List code-signing identities in your own Keychain:

```sh
security find-identity -v -p codesigning
```

- If you already have a valid identity, pass its name to the installer:

```sh
TRANSLATOR_SIGNING_IDENTITY="Your Local Code Signing Identity" bash scripts/install.sh
```

- Replace the example with the name reported by `security`.
- Quit Translator before installation.
- Keep the same identity on future installations. Do not create a new certificate for every build.
- To use the same identity for development or tests:

```sh
xcodegen generate
xcodebuild -scheme Translator -destination 'platform=macOS' -derivedDataPath build \
    CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="Your Local Code Signing Identity" test
```

## Create a certificate, if needed

- Certificate setup changes your Keychain and trust settings. It is optional and is not part of the installer.
- Use Keychain Access → Certificate Assistant → Create a Certificate.
- Choose **Self Signed Root** as the identity type and **Code Signing** as the certificate type.
- Keep the private key in your own login Keychain.
- If you change trust settings, restrict trust to code signing. Do not enable general or TLS trust for this purpose.
- The example [`scripts/local-signing.cnf`](../scripts/local-signing.cnf) records the certificate profile used during development. It contains no certificate, private key, or password.
- Confirm that `security find-identity -v -p codesigning` lists the new identity before using it.
- This repository does not automate certificate generation, Keychain import, or trust changes.

## Accessibility approval

- Keep the installed app at `~/Applications/Translator.app`.
- Grant permission to that copy, not a separate development build.
- Switching from ad-hoc signing to a certificate can require a fresh approval.
- If an old entry does not grant access, quit Translator, remove the old entry, add the installed copy, enable it, and reopen the app.
- Stable signing reduces identity changes. Permission retention still depends on macOS and needs testing on your Mac.

## Inspect a build

```sh
codesign --verify --deep --strict ~/Applications/Translator.app
codesign -d -r- ~/Applications/Translator.app
```

- A certificate-signed build has a designated requirement that includes the bundle identifier and certificate identity.
- An ad-hoc build has a code-hash-based requirement that can change after rebuilding.
- Never commit signing keys, certificates, PKCS#12 files, or Keychain passwords.
