# Harold

Harold is a native macOS browser and research app built with SwiftUI. Enter a website or ask a question to get a brief with links to source material.

## Build and launch

Requires macOS 14 or newer and a Swift 5.9 or newer toolchain. On Allan’s machine, connect `/Volumes/MyPassport` before building or running an Xcode toolchain command.

```sh
./Scripts/build-app.sh
open dist/Harold.app
```

The script builds and ad hoc signs a local app bundle. Use `./Scripts/build-app.sh release` for an optimized build.

## Try it

- Harold opens with a sample about lunar exploration. Try **Solar vs. wind** or **History of GPS** to see a different card layout.
- Select a citation or source title to open the page in Harold. Use **Research** to return to your brief, or select **Browser** in the sidebar to reopen the last page.
- Click the star in the browser toolbar to add or remove a bookmark. Bookmarks are saved on this Mac and are also available in the sidebar. Right-click a saved entry to remove it.
- Click **Chat** to open or close the sidebar. Chat uses the Gemini key from Settings and remembers the current conversation while the workspace is open.
- **Listen** reads the summary aloud. The microphone button fills the question field from dictation. Allow microphone and speech recognition access when macOS asks.
- **Shift-Command-N** clears the current workspace. **Command-Comma** opens Settings.

## Live research

Open **Settings** and enter a [Tavily key](https://app.tavily.com/) and a [Gemini key](https://aistudio.google.com/apikey). Harold stores them in your macOS Keychain. Saving empty fields switches back to demo mode.

Tavily finds up to six sources. Gemini receives the question and excerpts and returns structured cards. Harold validates card contents and only links to source URLs returned by search. **Ask a follow-up** carries the previous question and summary forward. Recent live briefs are saved on this Mac. Depending on language and system support, macOS dictation may send audio to Apple’s speech service.

Provider references: [Tavily Search](https://docs.tavily.com/documentation/api-reference/endpoint/search), [Gemini Interactions](https://ai.google.dev/api/interactions-api-v1).

## Connect Firebase

1. In the Firebase Console, enable **Authentication → Sign-in method → Email/Password**.
2. Copy the **Web API Key** from the Firebase project's general settings.
3. In Harold, open **Account**, enter the key, and select **Connect Firebase**. Use **Create account** or sign in with an existing email and password.

Harold uses the project's Firebase Authentication service for sign-in, registration and password reset. The refresh token is stored in macOS Keychain. Bookmarks are local to the Mac. [Firebase Auth REST API](https://firebase.google.com/docs/reference/rest/auth)
