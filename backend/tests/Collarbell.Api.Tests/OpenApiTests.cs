namespace Collarbell.Api.Tests;

[Collection(ApiCollection.Name)]
public sealed class OpenApiTests(ApiFactory api)
{
    [Fact]
    public async Task Document_lists_the_v1_endpoints()
    {
        var json = await api.CreateClient().GetStringAsync("/openapi/v1.json", TestContext.Current.CancellationToken);

        Assert.Contains("\"/api/v1/me\"", json, StringComparison.Ordinal);
        Assert.Contains("\"/api/v1/pets\"", json, StringComparison.Ordinal);
        Assert.Contains("\"/api/v1/files\"", json, StringComparison.Ordinal);
        Assert.Contains("\"/api/v1/pets/{petId}/documents\"", json, StringComparison.Ordinal);
        Assert.Contains("\"/api/v1/pets/{id}/passport\"", json, StringComparison.Ordinal);
    }
}
