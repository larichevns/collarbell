using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using Microsoft.Extensions.Configuration;

var builder = DistributedApplication.CreateBuilder(args);

var postgres = builder.AddPostgres("postgres")
    .WithDataVolume("collarbell-postgres-data")
    .WithLifetime(ContainerLifetime.Persistent);

var database = postgres.AddDatabase("collarbelldb");

// Photos and documents: SeaweedFS with an S3 API on a fixed port, so download links work in the simulator and on a phone.
var storage = builder.AddSeaweedFS("storage")
    .WithS3(s3Port: 8333)
    .WithDataVolume("collarbell-storage-data")
    .WithLifetime(ContainerLifetime.Persistent);

// The Firebase project id lives in Collarbell.Api/appsettings.json (it is not a secret).
var api = builder.AddProject<Projects.Collarbell_Api>("api")
    .WithReference(database)
    .WithReference(storage)
    .WaitFor(database)
    .WaitFor(storage)
    .WithExternalHttpEndpoints();

// The Gemini key: dotnet user-secrets set "Parameters:gemini-api-key" "<key>" in this project. Without it the app
// runs locally, only reading photos with AI is off. A deployment always asks for it.
if (builder.ExecutionContext.IsPublishMode || !string.IsNullOrWhiteSpace(builder.Configuration["Parameters:gemini-api-key"]))
{
    var geminiKey = builder.AddParameter("gemini-api-key", secret: true);
    api.WithEnvironment("Ai__Gemini__ApiKey", geminiKey);
}

// The Firebase service account key that sends pushes (JSON, from the Firebase console: Project settings → Service
// accounts): dotnet user-secrets set "Parameters:firebase-service-account" "<json>" in this project. Without it
// reminders are planned and listed, only not pushed to phones.
if (builder.ExecutionContext.IsPublishMode || !string.IsNullOrWhiteSpace(builder.Configuration["Parameters:firebase-service-account"]))
{
    var firebaseKey = builder.AddParameter("firebase-service-account", secret: true);
    api.WithEnvironment("Notifications__FirebaseCredentials", firebaseKey);
}

// A real phone on the home Wi-Fi: dotnet run --launch-profile phone. The API and the file links then listen on every
// address of the Mac, and links point to its address in the home network. The X-Dev-User sign-in is off, since anyone
// on the network could use it: the phone signs in with Firebase. Postgres and the dashboard stay on this Mac only.
if (builder.Configuration.GetValue<bool>("Phone:Enabled"))
{
    var address = builder.Configuration["Phone:LanAddress"] ?? LanAddress()
        ?? throw new InvalidOperationException("The Mac has no address in a home network (Wi-Fi or Ethernet); set Phone:LanAddress.");
    api.WithEndpoint("http", e => e.TargetHost = "0.0.0.0")
        .WithEnvironment("Auth__DevUsers__Enabled", "false")
        .WithEnvironment("Storage__PublicEndpoint", $"http://{address}:8333");
    storage.WithEndpoint("s3", e => e.TargetHost = "0.0.0.0");
}

builder.Build().Run();

// The Mac's IPv4 address on Wi-Fi or Ethernet (en0, en1…): the one a phone on the same network reaches.
static string? LanAddress() =>
    NetworkInterface.GetAllNetworkInterfaces()
        .Where(n => n.OperationalStatus == OperationalStatus.Up && n.Name.StartsWith("en", StringComparison.Ordinal))
        .SelectMany(n => n.GetIPProperties().UnicastAddresses)
        .Select(a => a.Address)
        .FirstOrDefault(a => a.AddressFamily == AddressFamily.InterNetwork
            && !IPAddress.IsLoopback(a)
            && !a.ToString().StartsWith("169.254.", StringComparison.Ordinal))
        ?.ToString();
