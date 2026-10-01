import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Marker prefix an uploaded picture is stored under, so a profile value can
/// be told apart from a preset (`avit://avatar/<index>`), a plain URL, or
/// nothing at all.
const String kAvatarDataPrefix = 'data:image/';

/// Longest edge a stored picture may keep. Anything larger is scaled down
/// before it is turned into [kAvatarDataPrefix] form.
const double kAvatarMaxEdge = 512;

/// JPEG quality used when re-encoding a chosen picture.
const int kAvatarJpegQuality = 82;

/// Ceiling on the encoded picture, so [AppUser.avatarUrl] stays small enough
/// for the key-value store that holds profile edits.
const int kMaxAvatarPhotoBytes = 200 * 1024;

/// True when [avatarUrl] holds an uploaded picture rather than a preset.
bool isAvatarPhoto(String? avatarUrl) =>
    avatarUrl != null && avatarUrl.startsWith(kAvatarDataPrefix);

/// Scales [bytes] into a [kAvatarMaxEdge] box and re-encodes them as a JPEG
/// data URI.
///
/// Returns null when the bytes are not a picture the platform can decode.
Future<String?> encodeAvatarPhoto(Uint8List bytes) async {
  try {
    final img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    final int width = decoded.width;
    final int height = decoded.height;
    if (width <= 0 || height <= 0) return null;

    final double scale = math.min(
      1.0,
      kAvatarMaxEdge / math.max(width, height),
    );
    final int targetWidth = math.max(1, (width * scale).round());
    final int targetHeight = math.max(1, (height * scale).round());

    final img.Image fitted = targetWidth == width && targetHeight == height
        ? decoded
        : img.copyResize(
            decoded,
            width: targetWidth,
            height: targetHeight,
            interpolation: img.Interpolation.average,
          );
    final Uint8List jpeg = Uint8List.fromList(
      img.encodeJpg(fitted, quality: kAvatarJpegQuality),
    );
    return '${kAvatarDataPrefix}jpeg;base64,${base64Encode(jpeg)}';
  } catch (_) {
    return null;
  }
}

/// Where the bytes for a picture come from — the real gallery on a device,
/// and a fixture in tests.
typedef PhotoSource = Future<Uint8List?> Function();

/// Turns chosen bytes into the value that goes into `avatarUrl`.
typedef PhotoEncoder = Future<String?> Function(Uint8List bytes);

/// The outcome of asking for a picture: a data URI, a cancellation, or a
/// message worth showing the student.
class AvatarPhotoResult {
  const AvatarPhotoResult.photo(String dataUri) : this._(dataUri: dataUri);
  const AvatarPhotoResult.cancelled() : this._();
  const AvatarPhotoResult.error(String message) : this._(error: message);

  const AvatarPhotoResult._({this.dataUri, this.error});

  final String? dataUri;
  final String? error;

  /// The student backed out; nothing should happen next.
  bool get wasCancelled => dataUri == null && error == null;
}

/// Chooses a picture and normalises it into something [isAvatarPhoto] accepts.
///
/// Both halves are injected: [source] supplies bytes and [encode] shapes them,
/// so the screen can be driven without a platform photo picker.
class AvatarPhotoPicker {
  AvatarPhotoPicker({required this.source, PhotoEncoder? encode})
    : _encode = encode ?? encodeAvatarPhoto;

  /// Supplies the raw picture bytes.
  final PhotoSource source;
  final PhotoEncoder _encode;

  Future<AvatarPhotoResult> pick() async {
    final Uint8List? bytes;
    try {
      bytes = await source();
    } catch (_) {
      return const AvatarPhotoResult.error(
        "We couldn't open your photo library.",
      );
    }
    if (bytes == null) return const AvatarPhotoResult.cancelled();

    final String? uri;
    try {
      uri = await _encode(bytes);
    } catch (_) {
      return const AvatarPhotoResult.error(
        "We couldn't use that picture. Please try another one.",
      );
    }
    if (uri == null) {
      return const AvatarPhotoResult.error(
        "We couldn't read that picture. Please try another one.",
      );
    }
    if (_decodedLength(uri) > kMaxAvatarPhotoBytes) {
      return const AvatarPhotoResult.error(
        'That picture is too large. Please pick a smaller one.',
      );
    }
    return AvatarPhotoResult.photo(uri);
  }

  /// Bytes a base64 data URI stands for.
  static int _decodedLength(String uri) {
    if (!uri.startsWith(kAvatarDataPrefix)) return uri.length;
    final int comma = uri.indexOf(',');
    if (comma < 0) return uri.length;
    return (uri.length - comma - 1) * 3 ~/ 4;
  }
}
