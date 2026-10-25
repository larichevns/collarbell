using System.Net;
using System.Net.Http.Json;
using Collarbell.Api.Infrastructure.Persistence;
using Collarbell.Api.Modules.Documents;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using SkiaSharp;
using static Collarbell.Api.Tests.TestData;

namespace Collarbell.Api.Tests;

[Collection(ApiCollection.Name)]
public sealed class FilesTests(ApiFactory api)
{
    [Fact]
    public async Task A_photo_is_stored_as_jpeg_without_exif_and_with_a_thumbnail()
    {
        var client = api.ClientFor($"upload-{Guid.NewGuid():N}");
        var original = Jpeg(1200, 900, withExif: true);
        Assert.True(HasExif(original));

        var file = await client.UploadFileAsync(original);

        Assert.Equal("image/jpeg", file.ContentType);
        Assert.Equal((1200, 900), (file.Width, file.Height));
        var stored = await api.Storage.GetByteArrayAsync(file.Url, Ct);
        Assert.False(HasExif(stored));
        Assert.Equal(stored.Length, file.SizeBytes);
        using var thumbnail = SKBitmap.Decode(await api.Storage.GetByteArrayAsync(file.ThumbnailUrl, Ct));
        Assert.Equal((480, 360), (thumbnail.Width, thumbnail.Height));
    }

    [Fact]
    public async Task A_big_png_is_scaled_down_to_2048_px()
    {
        var client = api.ClientFor($"big-{Guid.NewGuid():N}");

        var file = await client.UploadFileAsync(Png(3000, 1000));

        Assert.Equal("image/jpeg", file.ContentType);
        Assert.Equal((2048, 683), (file.Width, file.Height));
    }

    [Fact]
    public async Task A_pdf_is_stored_as_it_is()
    {
        var client = api.ClientFor($"pdf-{Guid.NewGuid():N}");

        var file = await client.UploadFileAsync(Pdf());

        Assert.Equal("application/pdf", file.ContentType);
        Assert.Null(file.ThumbnailUrl);
        Assert.Equal(Pdf(), await api.Storage.GetByteArrayAsync(file.Url, Ct));
    }

    [Fact]
    public async Task Other_files_are_rejected_by_their_content_not_their_name()
    {
        var client = api.ClientFor($"fake-{Guid.NewGuid():N}");

        var response = await client.UploadAsync("<html>not a photo</html>"u8.ToArray(), fileName: "cat.jpg");

        Assert.Equal(HttpStatusCode.UnsupportedMediaType, response.StatusCode);
    }

    [Fact]
    public async Task Files_over_15_mb_are_rejected()
    {
        var client = api.ClientFor($"huge-{Guid.NewGuid():N}");
        var tooBig = new byte[(15 * 1024 * 1024) + 1];
        "%PDF-"u8.CopyTo(tooBig);

        var response = await client.UploadAsync(tooBig);

        Assert.Equal(HttpStatusCode.RequestEntityTooLarge, response.StatusCode);
    }

    [Fact]
    public async Task Links_are_given_only_to_the_household_that_owns_the_file()
    {
        var anna = api.ClientFor($"anna-{Guid.NewGuid():N}");
        var oleg = api.ClientFor($"oleg-{Guid.NewGuid():N}");
        var file = await anna.UploadPhotoAsync();

        var annasLink = await anna.GetFromJsonAsync<FileLink>($"/api/v1/files/{file.Id}/url", Ct);
        var olegsResponse = await oleg.GetAsync($"/api/v1/files/{file.Id}/url", Ct);

        Assert.Equal(file.Id, annasLink!.Id);
        Assert.Equal(HttpStatusCode.NotFound, olegsResponse.StatusCode);
    }

    [Fact]
    public async Task Storage_links_need_their_signature()
    {
        var client = api.ClientFor($"signed-{Guid.NewGuid():N}");
        var file = await client.UploadPhotoAsync();

        var unsigned = new Uri(file.Url).GetLeftPart(UriPartial.Path);

        Assert.Equal(HttpStatusCode.OK, (await api.Storage.GetAsync(file.Url, Ct)).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await api.Storage.GetAsync(unsigned, Ct)).StatusCode);
    }

    [Fact]
    public async Task Uploads_never_attached_are_deleted_after_a_day()
    {
        var client = api.ClientFor($"abandoned-{Guid.NewGuid():N}");
        var fresh = await client.UploadPhotoAsync();
        var old = await client.UploadPhotoAsync();
        await using (var scope = api.Services.CreateAsyncScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            await db.StoredFiles.Where(f => f.Id == old.Id)
                .ExecuteUpdateAsync(s => s.SetProperty(f => f.CreatedAt, DateTimeOffset.UtcNow.AddDays(-2)), Ct);
        }

        await api.RunStorageCleanupAsync();

        Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync($"/api/v1/files/{old.Id}/url", Ct)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await api.Storage.GetAsync(old.Url, Ct)).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync($"/api/v1/files/{fresh.Id}/url", Ct)).StatusCode);
    }
}
