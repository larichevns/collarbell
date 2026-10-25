using System.Security.Cryptography;
using SkiaSharp;

namespace Collarbell.Api.Modules.Documents;

/// <summary>What an upload becomes: the bytes to store, their type and, for photos, the size and a thumbnail.</summary>
internal sealed record PreparedFile(byte[] Content, string ContentType, int? Width, int? Height, byte[]? Thumbnail)
{
    public string Sha256 => Convert.ToHexStringLower(SHA256.HashData(Content));
}

/// <summary>
/// Checks an upload and turns it into what we store.
/// <list type="bullet">
/// <item>The type is decided by the file's first bytes, never by its name or the type the client declared.</item>
/// <item>Photos are decoded and encoded again as JPEG: this drops EXIF (it can hold the location)
/// and anything else hidden in the file, turns the picture upright and limits its size.</item>
/// <item>PDFs are stored as they are.</item>
/// </list>
/// </summary>
internal static class FilePreparation
{
    public const long MaxUploadBytes = 15 * 1024 * 1024;

    private const int MaxImageSide = 2048;
    private const int ThumbnailSide = 480;
    private const long MaxSourcePixels = 60_000_000;

    /// <summary>Null when the file is not a JPEG, PNG or WebP photo or a PDF, or the photo can't be decoded.</summary>
    public static PreparedFile? Prepare(byte[] upload)
    {
        if (IsPdf(upload))
        {
            return new PreparedFile(upload, "application/pdf", null, null, null);
        }

        return IsSupportedImage(upload) ? PrepareImage(upload) : null;
    }

    private static bool IsPdf(ReadOnlySpan<byte> file) => file.StartsWith("%PDF-"u8);

    private static bool IsSupportedImage(ReadOnlySpan<byte> file) =>
        file.StartsWith((ReadOnlySpan<byte>)[0xFF, 0xD8, 0xFF])                                        // JPEG
        || file.StartsWith((ReadOnlySpan<byte>)[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])      // PNG
        || (file.Length >= 12 && file[..4].SequenceEqual("RIFF"u8) && file[8..12].SequenceEqual("WEBP"u8)); // WebP

    private static PreparedFile? PrepareImage(byte[] upload)
    {
        using var data = SKData.CreateCopy(upload);
        using var codec = SKCodec.Create(data);
        if (codec is null || (long)codec.Info.Width * codec.Info.Height > MaxSourcePixels)
        {
            return null;
        }

        // JPEG decodes at 1/2, 1/4… of the size directly, which keeps big camera photos cheap.
        var scale = Math.Min(1f, (float)MaxImageSide / Math.Max(codec.Info.Width, codec.Info.Height));
        var size = codec.GetScaledDimensions(scale);
        using var pixels = new SKBitmap(new SKImageInfo(size.Width, size.Height, SKColorType.Rgba8888, SKAlphaType.Premul));
        var result = codec.GetPixels(pixels.Info, pixels.GetPixels());
        if (result is not (SKCodecResult.Success or SKCodecResult.IncompleteInput))
        {
            return null;
        }

        var photo = EncodeUpright(pixels, codec.EncodedOrigin, MaxImageSide, quality: 85, out var width, out var height);
        var thumbnail = EncodeUpright(pixels, codec.EncodedOrigin, ThumbnailSide, quality: 80, out _, out _);
        return new PreparedFile(photo, "image/jpeg", width, height, thumbnail);
    }

    /// <summary>Draws the pixels upright, at most <paramref name="maxSide"/> pixels on the long side, on white, as JPEG.</summary>
    private static byte[] EncodeUpright(SKBitmap pixels, SKEncodedOrigin origin, int maxSide, int quality, out int width, out int height)
    {
        var sidesSwap = origin is SKEncodedOrigin.LeftTop or SKEncodedOrigin.RightTop
            or SKEncodedOrigin.RightBottom or SKEncodedOrigin.LeftBottom;
        var (uprightWidth, uprightHeight) = sidesSwap ? (pixels.Height, pixels.Width) : (pixels.Width, pixels.Height);
        var scale = Math.Min(1f, (float)maxSide / Math.Max(uprightWidth, uprightHeight));
        width = Math.Max(1, (int)MathF.Round(uprightWidth * scale));
        height = Math.Max(1, (int)MathF.Round(uprightHeight * scale));

        using var surface = SKSurface.Create(new SKImageInfo(width, height, SKColorType.Rgba8888, SKAlphaType.Premul));
        var canvas = surface.Canvas;
        canvas.Clear(SKColors.White); // transparent parts of a PNG become white
        canvas.Scale(scale);
        canvas.Concat(UprightMatrix(origin, pixels.Width, pixels.Height));
        using var image = SKImage.FromBitmap(pixels);
        canvas.DrawImage(image, 0, 0, new SKSamplingOptions(SKFilterMode.Linear, SKMipmapMode.Linear));

        using var snapshot = surface.Snapshot();
        using var jpeg = snapshot.Encode(SKEncodedImageFormat.Jpeg, quality);
        return jpeg.ToArray();
    }

    /// <summary>
    /// Maps stored pixels to the upright picture for each EXIF orientation:
    /// x' = scaleX·x + skewX·y + transX, y' = skewY·x + scaleY·y + transY.
    /// </summary>
    private static SKMatrix UprightMatrix(SKEncodedOrigin origin, int w, int h) => origin switch
    {
        SKEncodedOrigin.TopRight => new SKMatrix(-1, 0, w, 0, 1, 0, 0, 0, 1),     // mirrored
        SKEncodedOrigin.BottomRight => new SKMatrix(-1, 0, w, 0, -1, h, 0, 0, 1), // upside down
        SKEncodedOrigin.BottomLeft => new SKMatrix(1, 0, 0, 0, -1, h, 0, 0, 1),   // mirrored upside down
        SKEncodedOrigin.LeftTop => new SKMatrix(0, 1, 0, 1, 0, 0, 0, 0, 1),       // transposed
        SKEncodedOrigin.RightTop => new SKMatrix(0, -1, h, 1, 0, 0, 0, 0, 1),     // turn 90° clockwise
        SKEncodedOrigin.RightBottom => new SKMatrix(0, -1, h, -1, 0, w, 0, 0, 1), // transverse
        SKEncodedOrigin.LeftBottom => new SKMatrix(0, 1, 0, -1, 0, w, 0, 0, 1),   // turn 90° counterclockwise
        _ => SKMatrix.Identity,
    };
}
