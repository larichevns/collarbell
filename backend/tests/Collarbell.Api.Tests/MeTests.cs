using System.Net;
using System.Net.Http.Json;
using Collarbell.Api.Infrastructure.Persistence;
using Collarbell.Api.Modules.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Collarbell.Api.Tests;

[Collection(ApiCollection.Name)]
public sealed class MeTests(ApiFactory api)
{
    private static CancellationToken Ct => TestContext.Current.CancellationToken;

    [Fact]
    public async Task Requests_without_sign_in_get_401_problem_details()
    {
        var response = await api.CreateClient().GetAsync("/api/v1/me", Ct);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);
    }

    [Fact]
    public async Task First_call_creates_user_and_household_and_later_calls_return_the_same()
    {
        var client = api.ClientFor($"first-{Guid.NewGuid():N}", "anna@example.com");

        var first = await client.GetFromJsonAsync<MeResponse>("/api/v1/me", Ct);
        var second = await client.GetFromJsonAsync<MeResponse>("/api/v1/me", Ct);

        Assert.NotNull(first);
        Assert.Equal("anna@example.com", first.Email);
        Assert.Equal(CurrentUserAccessor.DefaultHouseholdName, first.Household.Name);
        Assert.Equal(first.Id, second!.Id);
        Assert.Equal(first.Household.Id, second.Household.Id);
    }

    [Fact]
    public async Task Parallel_first_calls_create_a_single_user()
    {
        var uid = $"race-{Guid.NewGuid():N}";
        var client = api.ClientFor(uid);

        var responses = await Task.WhenAll(Enumerable.Range(0, 5).Select(_ => client.GetFromJsonAsync<MeResponse>("/api/v1/me", Ct)));

        Assert.Single(responses.Select(r => r!.Id).Distinct());
        await using var scope = api.Services.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(1, await db.Users.CountAsync(u => u.AuthSubject == $"dev:{uid}", Ct));
        Assert.Equal(1, await db.HouseholdMembers.CountAsync(m => m.UserId == responses[0]!.Id, Ct));
    }

    [Fact]
    public async Task Update_sets_locale_and_time_zone_for_user_and_owned_household()
    {
        var client = api.ClientFor($"tz-{Guid.NewGuid():N}");

        var response = await client.PutAsJsonAsync("/api/v1/me", new UpdateMeRequest("Anna", "ru", "Europe/Berlin"), Ct);
        var me = await response.Content.ReadFromJsonAsync<MeResponse>(Ct);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("Anna", me!.DisplayName);
        Assert.Equal("ru", me.Locale);
        Assert.Equal("Europe/Berlin", me.TimeZone);
        Assert.Equal("Europe/Berlin", me.Household.TimeZone);
    }

    [Theory]
    [InlineData("{\"timeZone\":\"Mars/Olympus\"}", "timeZone")]
    [InlineData("{\"timeZone\":\"CET\"}", "timeZone")]
    [InlineData("{\"locale\":\"de\"}", "locale")]
    public async Task Update_rejects_invalid_values(string body, string field)
    {
        var client = api.ClientFor($"bad-{Guid.NewGuid():N}");

        var response = await client.PutAsync("/api/v1/me", new StringContent(body, System.Text.Encoding.UTF8, "application/json"), Ct);
        var problem = await response.Content.ReadAsStringAsync(Ct);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Contains($"\"{field}\"", problem, StringComparison.Ordinal);
    }

    [Fact]
    public async Task Malformed_dev_user_header_is_rejected()
    {
        var client = api.ClientFor("not a valid uid!");

        var response = await client.GetAsync("/api/v1/me", Ct);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
}
