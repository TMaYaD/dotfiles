---
name: drive-android
description: Drive an Android emulator or connected device through adb without blowing context on screenshots. Prefer uiautomator2 (XML hierarchy + element actions) over screencap; when pixels are unavoidable, delegate the capture and parse to a subagent. Use when the user wants to automate, test, inspect, or interact with an Android device/emulator over adb.
allowed-tools: Bash, Read, Write, Edit, Agent
---

# Drive Android (adb + uiautomator2)

You are driving a real or emulated Android device. Screenshots are expensive: a single PNG burns thousands of tokens and a UI flow can easily exhaust the context window. The cardinal rule is **read the UI as structured text, not pixels**.

## The hierarchy of interaction

Always prefer the highest tier that can answer the question.

| Tier | Tool | Use for |
|------|------|---------|
| 1 | **uiautomator2** (Python) | Inspect, find, click, type, swipe, scroll, wait — 95% of cases |
| 2 | **adb shell** primitives (`input`, `am`, `pm`, `content`, `dumpsys`, `getprop`, `logcat`) | Launching apps, intents, system state, key events, package info |
| 3 | **uiautomator dump** (raw XML) | When uiautomator2 is unavailable but you still want structure, not pixels |
| 4 | **screencap (subagent only)** | Last resort: visual-only checks (color, image content, custom-rendered canvases) |

Never call `adb exec-out screencap` and read the PNG yourself. Always delegate that to a subagent (see "Tier 4" below).

## Preflight

```bash
adb devices                      # confirm device/emulator is attached and authorized
adb shell getprop ro.build.version.release   # Android version
python3 -c "import uiautomator2" 2>/dev/null || pip install --user uiautomator2
```

If multiple devices are attached, set `ANDROID_SERIAL` or pass `-s <serial>` to every adb call. Ask the user which device if ambiguous.

First run of uiautomator2 against a device:

```bash
python3 -m uiautomator2 init   # installs the on-device atx-agent + uiautomator apks
```

## Tier 1: uiautomator2 (preferred)

Drive a small Python helper rather than dozens of one-off shell calls. The XML hierarchy + selectors give you durable, readable state without screenshots.

```python
import uiautomator2 as u2
d = u2.connect()                          # or u2.connect("emulator-5554")

# Inspect — these return text/structured data, NOT images:
d.dump_hierarchy()                        # full XML tree (filter before printing!)
d.app_current()                           # {package, activity, pid}
d(resourceId="com.app:id/login").info     # bounds, text, enabled, etc.

# Act:
d(text="Sign in").click()
d(resourceId="com.app:id/email").set_text("a@b.co")
d(description="Menu").click()
d.swipe_ext("up", scale=0.8)
d.press("back")

# Wait — far better than sleep():
d(text="Welcome").wait(timeout=10)
d(resourceId="com.app:id/spinner").wait_gone(timeout=15)
```

**Context discipline when dumping hierarchy:**

`d.dump_hierarchy()` can be enormous. Never dump it raw into the conversation. Instead:

1. Pipe it through a Python filter that extracts only nodes matching what you care about (resource-id, text, content-desc, class). Print just those.
2. Or query directly with selectors (`d(text=...)`, `d(resourceIdMatches=...)`) and print only `.info` for the matches.
3. If you must inspect broadly, write the XML to a temp file and grep it from Bash, then read only the relevant lines.

```bash
# Example: find every clickable node mentioning "login"
python3 - <<'PY'
import uiautomator2 as u2, re
xml = u2.connect().dump_hierarchy()
for m in re.finditer(r'<node[^>]*clickable="true"[^>]*>', xml):
    if 'login' in m.group(0).lower():
        print(m.group(0))
PY
```

## Tier 2: adb shell primitives

Use these directly — they don't require uiautomator2 and don't produce screenshots.

```bash
adb shell am start -n com.app/.MainActivity         # launch activity
adb shell am start -a android.intent.action.VIEW -d "https://..."
adb shell input tap <x> <y>                          # only with known coords
adb shell input text "hello"                         # caveat: spaces -> %s
adb shell input keyevent KEYCODE_BACK                # 4=BACK 3=HOME 82=MENU 66=ENTER
adb shell input swipe <x1> <y1> <x2> <y2> <ms>
adb shell pm list packages | grep <fragment>
adb shell dumpsys window windows | grep -E 'mCurrentFocus|mFocusedApp'
adb shell dumpsys activity top | head -50            # top activity + view tree
adb logcat -d -t 200 <TAG>:* *:S                     # bounded logcat slice
```

`dumpsys activity top` is a hidden gem — it gives you the focused activity and a textual view tree without a screenshot.

## Tier 3: raw uiautomator dump (fallback)

When uiautomator2 isn't installed and you can't install it:

```bash
adb shell uiautomator dump /sdcard/ui.xml
adb pull /sdcard/ui.xml /tmp/ui.xml
# Then grep/parse /tmp/ui.xml — never paste it whole into the conversation.
```

## Tier 4: screencap — DELEGATE to a subagent

Only resort to pixels when the answer truly cannot come from the view hierarchy: custom-rendered canvases (games, charts, maps, video frames), visual regression checks, color/theme verification, or CAPTCHAs the user explicitly asked you to read.

**Never** capture or read the PNG in the main conversation. Spawn a subagent with a precise question and let it return a short text answer.

Use the Agent tool with `subagent_type: "general-purpose"`. The prompt must:

1. State the exact device/serial (or how to pick one).
2. State the exact question — what the subagent is looking for.
3. Tell it to capture into `/tmp/` (e.g., `adb exec-out screencap -p > /tmp/scr-<ts>.png`), inspect via Read (image), and discard.
4. Cap the answer ("reply in under 100 words", "answer yes/no plus one sentence").
5. Forbid pasting raw image data or base64 back.

Example:

```
Agent({
  description: "Verify login button color",
  subagent_type: "general-purpose",
  prompt: "On device emulator-5554, capture the current screen with
    `adb -s emulator-5554 exec-out screencap -p > /tmp/scr.png`, then Read
    /tmp/scr.png. Question: is the primary 'Sign in' button rendered in the
    brand purple (~#6B4EFF) or did it fall back to the default blue?
    Answer in under 40 words: color name + hex estimate + yes/no on brand
    match. Do not paste image data."
})
```

If you need several visual checks in one flow, batch them into a single subagent call (one capture, multiple questions) rather than spawning a subagent per check.

## Common task recipes

**Launch app and wait for first screen:**
```python
d.app_start("com.app", stop=True)
d(resourceId="com.app:id/home_root").wait(timeout=15)
```

**Type into a field by label:**
```python
d(text="Email").right(className="android.widget.EditText").set_text("a@b.co")
```

**Scroll until visible:**
```python
d(scrollable=True).scroll.to(text="Settings")
```

**Grant a runtime permission without UI:**
```bash
adb shell pm grant com.app android.permission.CAMERA
```

**Reset app state between runs:**
```bash
adb shell pm clear com.app
```

## Anti-patterns

- **Do NOT** `adb exec-out screencap -p > foo.png` and Read it yourself — always delegate to a subagent.
- **Do NOT** print full `dump_hierarchy()` output into the conversation — filter first.
- **Do NOT** `sleep` to wait for UI; use `.wait(timeout=...)` / `.wait_gone(...)`.
- **Do NOT** tap by hardcoded `(x, y)` when a selector exists — pixel coordinates break across screen sizes and orientations.
- **Do NOT** loop screencap to "watch" the UI; poll the hierarchy or `dumpsys` instead.
- **Do NOT** install uiautomator2 globally without asking; prefer `pip install --user` or a venv.
- **Do NOT** assume a single device — check `adb devices` and pin `-s <serial>` when there's more than one.
