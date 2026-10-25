using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace Collarbell.Api.Infrastructure.Persistence;

/// <summary>Used by <c>dotnet ef</c> only: migrations are generated without connecting to a database.</summary>
public sealed class DesignTimeDbContextFactory : IDesignTimeDbContextFactory<AppDbContext>
{
    public AppDbContext CreateDbContext(string[] args) =>
        new(new DbContextOptionsBuilder<AppDbContext>()
            .UseNpgsql("Host=localhost;Database=collarbell_design")
            .UseSnakeCaseNamingConvention()
            .Options);
}
