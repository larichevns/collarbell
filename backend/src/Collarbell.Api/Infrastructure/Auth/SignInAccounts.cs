using FirebaseAdmin;
using FirebaseAdmin.Auth;
using Google.Apis.Auth.OAuth2;

namespace Collarbell.Api.Infrastructure.Auth;

/// <summary>
/// The sign-in accounts: Firebase Authentication holds each person's e-mail and password. Deleting a Collarbell account
/// deletes its sign-in account too (spec, "Удаление аккаунта"). Firebase in the app, a fake in the tests.
/// </summary>
public interface ISignInAccounts
{
    /// <summary>
    /// Deletes the sign-in account of <paramref name="subject"/> (a Firebase uid). True when it is gone, also when it was
    /// gone already; false when it couldn't be deleted now and has to be tried again later.
    /// </summary>
    Task<bool> DeleteAsync(string subject, CancellationToken ct);
}

/// <summary>
/// Deletes Firebase sign-in accounts with the Admin SDK and the same service account key the pushes use
/// (<c>Notifications:FirebaseCredentials</c>: Firebase's own key may manage the project's users).
/// </summary>
public sealed class FirebaseSignInAccounts : ISignInAccounts
{
    /// <summary>The prefix of local dev users (<see cref="DevUserAuthenticationHandler"/>): they have no Firebase account.</summary>
    private const string DevPrefix = "dev:";

    private readonly FirebaseAuth? _auth;
    private readonly ILogger<FirebaseSignInAccounts> _log;

    public FirebaseSignInAccounts(IConfiguration configuration, ILogger<FirebaseSignInAccounts> log)
    {
        _log = log;
        var json = configuration["Notifications:FirebaseCredentials"];
        if (string.IsNullOrWhiteSpace(json))
        {
            return;
        }

        try
        {
            var account = CredentialFactory.FromJson<ServiceAccountCredential>(json);
            var projectId = configuration["Firebase:ProjectId"];
            if (!string.IsNullOrWhiteSpace(projectId) && account.ProjectId != projectId)
            {
                // Another project's key would delete nobody, and every "user not found" would look like success.
                log.LogError("The Firebase key is for project {KeyProject}, the app uses {AppProject}: sign-in accounts aren't deleted.",
                    account.ProjectId, projectId);
                return;
            }

            const string appName = "collarbell-sign-in";
            var app = FirebaseApp.GetInstance(appName) ?? FirebaseApp.Create(
                new AppOptions { Credential = account.ToGoogleCredential(), ProjectId = account.ProjectId }, appName);
            _auth = FirebaseAuth.GetAuth(app);
        }
        catch (Exception e)
        {
            log.LogError(e, "The Firebase key in Notifications:FirebaseCredentials isn't a valid service account key: sign-in accounts aren't deleted.");
        }
    }

    public async Task<bool> DeleteAsync(string subject, CancellationToken ct)
    {
        if (subject.StartsWith(DevPrefix, StringComparison.Ordinal))
        {
            return true;
        }

        if (_auth is null)
        {
            _log.LogWarning("No Firebase key: the sign-in account of a deleted account waits to be deleted.");
            return false;
        }

        try
        {
            await _auth.DeleteUserAsync(subject, ct);
            return true;
        }
        catch (FirebaseAuthException e) when (e.AuthErrorCode == AuthErrorCode.UserNotFound)
        {
            return true;
        }
        catch (Exception e) when (!ct.IsCancellationRequested)
        {
            _log.LogWarning(e, "Could not delete a sign-in account in Firebase; it is tried again later.");
            return false;
        }
    }
}
