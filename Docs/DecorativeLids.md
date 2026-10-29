# Custom closing-lid images

Enable **Decorative DS Lids** in Experimental Features (beta builds). On iPhone Duo, open **Settings → Controller Skins → Nintendo DS → Inside or Outside**, then tap **Closed-Lid Cover…** below a controller skin preview.

Import your own still PNG/JPEG, preview the result, or reset to the existing skin/default cover. The choice persists per controller skin identifier. No images or presets are bundled. The existing closing-lid animation, hinge handling, sleep behavior, charging behavior, and Show Cover Skins setting remain in use.

Image references use a hidden `@Option`; imported files stay in local Application Support storage. Imports are limited to 30 MB, normalize EXIF orientation, and downsample to a maximum edge of 2048 pixels. Invalid imports preserve the current choice. Missing files fall back to the existing cover. Reset removes the imported image. No cloud sync or skin-format change is introduced.

## Validation

Run `Tests/LidCovers/run.sh` on macOS to test the production image importer, including PNG/JPEG decoding, EXIF rotation, downsampling, and corrupt/unsupported/oversized file rejection.

An unsigned arm64 iOS Simulator build is checked with Xcode 27.1. No simulator runtime or physical iPhone Duo is available, so settings navigation, import UI, and closing/reopening behavior still need device testing.
