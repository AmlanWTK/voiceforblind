# শুনি (Shuni)

A voice-first learning app for blind and visually impaired children in Bangladesh.
A child opens the app, hears a Bangla greeting, asks for their class's books by voice,
chooses a book and starts a lesson. Nothing on screen has to be seen to do this.

**Flow:** app opens → greeting → "তুমি কোন শ্রেণির বই পড়তে চাও?" → child answers
("ক্লাস ওয়ানের বই", "প্রথম শ্রেণি", "Class 1 er boi" …) → Class 1 books (titles read in the
narrator's own voice) → child picks a book ("বাংলা বই পড়ব") → child picks a lesson
("প্রথম পাঠ", "পাঠ ৯", "বাঘ ও রাখাল", or "সূচি" to hear the names) → the lesson's recorded
narration plays with the text and pictures on screen.

## Content

Two NCTB Class 1 books, both DAISY 3 talking books with human narration, sentence-level
sync (SMIL), full text and a spoken description of every picture:

| Folder | Book | Structure |
|---|---|---|
| `assets/AmarBanglaBoiClass1DaisyMultimedia/` | আমার বাংলা বই – প্রথম শ্রেণি | 53 lessons (পাঠ ১–৫৩) |
| `assets/EnglishClassOneDaisyMultimedia/` | English For Today – Class One | 5 units, 39 lessons (Lesson 1… in each unit) |

For a book with units the app first asks "কোন ইউনিট পড়তে চাও?", then that unit's lessons.
Children can also say both at once: "ইউনিট দুই পাঠ তিন", "দ্বিতীয় ইউনিটের তৃতীয় পাঠ",
"Unit 2 Lesson 3". In the lesson player "পাঠ ৩" means lesson 3 of the current unit, and
"পরের পাঠ" carries on into the next unit.

The app does not parse DAISY at runtime. `tools/build_daisy_catalog.py` reads the DAISY
files and writes `assets/library/catalog.json` (titles, units, lessons, timings, text,
picture descriptions, page numbers). It also merges a lesson that the DAISY book splits
over two recordings (English Unit 2 Lesson 10). `tools/library_config.json` says which
folder belongs to which class and what children may call each book ("বাংলা বই",
"ইংরেজি বই", "ইংলিশ" …).

To add a book: copy its DAISY folder into `assets/`, add it to `tools/library_config.json`,
add the folder to `pubspec.yaml` under `assets:`, then run:

```
python tools/build_daisy_catalog.py
```

## Code map

| Path | What it does |
|---|---|
| `lib/main.dart`, `lib/app/` | App root, theme, shared scope |
| `lib/content/` | Catalog models and loader |
| `lib/voice/intent_parser.dart` | Understands Bangla / English / Banglish replies (pure Dart, unit-tested) |
| `lib/voice/bangla_text.dart` | Normalisation, Bangla number words, digits |
| `lib/voice/prompts.dart` | Every sentence the app speaks |
| `lib/voice/voice_controller.dart` | Speak → listen → retry sequencing with cancellation |
| `lib/services/` | `flutter_tts` (Bangla TTS), `speech_to_text` (one-shot recognition), `just_audio` (clips) |
| `lib/screens/` | Home, Class books, Book (lesson chooser), Lesson player |

## Voice behaviour

- The microphone is on only after a question, for at most ~8 s (3 s of silence ends it). There is no continuous listening.
- If a reply is not understood, the app asks once more, then explains the on-screen buttons and waits.
- A bare number ("এক"), or a reply the recogniser was unsure about, is confirmed with a yes/no question before acting.
- Microphone denied, no recogniser, no Bangla recognition, or no internet: the app says so in Bangla and points to the buttons.
- Every control has a Bangla TalkBack label. Touch targets are 56–196 dp.

## Run and test

```
flutter pub get
flutter analyze
flutter test
flutter run            # on an Android phone, preferably a real device
```

The device needs:
- A Bangla TTS voice: Settings → Text-to-speech → Google → install Bangla (বাংলা).
- Google speech recognition with Bangla: the Google app, plus Bangla offline speech if possible.
