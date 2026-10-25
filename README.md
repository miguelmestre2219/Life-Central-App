# Life Central

One iPhone app for money, travel, workouts and the rest of everyday life.
Everything is stored on the phone, with an encrypted backup in iCloud Drive.

- **Today**: what's on today across every area, quick add, search.
- **Money**: spending and income in any currency, categories, a monthly plan, bills.
- **Travel**: trips, day-by-day plans, maps, tickets, trip budget, packing, sending a day to Google Maps.
- **Fitness**: a workout library and calendar, live workout tracking with rest timer, suggestions and records, animated exercise guides.
- **Health**: Apple Health metrics with charts, plus weight, water and mood logging.
- **More**: documents (scan, file or photo), habits, tasks, meals and shopping, friends, settings and backup.

## Put it on your iPhone

You need a Mac with Xcode (free from the App Store), an iPhone on iOS 17 or later,
and an Apple ID. A paid developer account isn't needed.

1. Install the project generator. If you don't have Homebrew yet, get it from
   [brew.sh](https://brew.sh) first.

   ```sh
   brew install xcodegen
   ```

2. Get the code and make the Xcode project:

   ```sh
   git clone https://github.com/miguelmestre2219/life-central-app.git
   cd life-central-app
   xcodegen generate
   open LifeCentral.xcodeproj
   ```

3. In Xcode, sign in with your Apple ID (Xcode > Settings > Accounts).

4. Click **LifeCentral** at the top of the file list, open **Signing & Capabilities**
   and pick your name under **Team**. If Xcode says the bundle identifier is taken,
   change it to something of your own, such as `com.yourname.lifecentral`.

5. Connect your iPhone with a cable. On the phone, turn on
   Settings > Privacy & Security > Developer Mode (it restarts).

6. Choose your iPhone at the top of the Xcode window and press **Run** (▶).

7. The first time, the phone won't open the app until you trust it:
   Settings > General > VPN & Device Management > your Apple ID > Trust.

### Keep your signing settings

`xcodegen generate` rebuilds the project from `project.yml`, which resets the team
you picked. To keep it, copy `Config/Local.xcconfig.example` to
`Config/Local.xcconfig` and fill in your team ID and bundle id. Xcode shows the
team ID under Build Settings > Development Team after you've picked it once.
`Local.xcconfig` isn't committed.

### Getting updates

```sh
git pull
xcodegen generate
```

Then press **Run** again. Your data stays on the phone.

### With a free Apple ID

Apps installed with a free account stop opening after 7 days. Connect the phone
and press **Run** again to renew; nothing is lost. A paid Apple Developer
membership makes it last a year and lets the app use iCloud directly, which is
what live sharing with friends will need.

## Backup

Settings > Backup sets up an encrypted backup:

1. Choose a backup password. It can be kept in iCloud Keychain so a new iPhone
   can restore without typing it.
2. Choose a folder in iCloud Drive (for example, make one called Life Central).

The app then backs up once a day when you leave it. Everything is encrypted on
the phone with your password (PBKDF2 and AES-256-GCM) before it's written, so
the files in iCloud Drive can't be read without it. Only new documents and
photos are uploaded each time.

To restore, open Settings > Backup > Restore from a backup, pick the same folder
and enter the password. Close the app and open it again to finish.

If the password is lost, the backup can't be opened.

## Project layout

```
project.yml              XcodeGen project description
Config/                  Signing settings
LifeCentral/
  App/                   App entry, tabs, navigation, starter data
  Core/                  Shared pieces: theme, components, money, dates,
                         exchange rates, reminders, Face ID, backup
  Models/                SwiftData models
  Features/              One folder per area
  Resources/             App icon and colours
tools/exercise-figures/  Python scripts for the exercise animations
```

The data models are ready for iCloud sync: every property has a default and
every relationship is optional, so turning on CloudKit later needs no rework.

## Exercise animations

The cartoon figures in the exercise guides are drawn in code from joint angles.
The poses are written and checked in Python, then turned into Swift:

```sh
cd tools/exercise-figures
pip install pillow
python3 preview.py squat deadlift   # writes sheet.png with key frames
python3 emit.py                     # rewrites LifeCentral/Features/Fitness/ExerciseData.swift
```

`poses.py` holds the movements, `meta.py` the names, steps and tips, and
`figure.py` the drawing, which matches the Swift version in `ExerciseFigure.swift`.

## Build check

Every push to GitHub builds the app for the iPhone simulator
(`.github/workflows/build.yml`), so a compile error shows up there before
it reaches your Mac.
