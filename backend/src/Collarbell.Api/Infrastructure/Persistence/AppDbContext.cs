using Collarbell.Api.Modules.Ai;
using Collarbell.Api.Modules.Appointments;
using Collarbell.Api.Modules.Billing;
using Collarbell.Api.Modules.Care;
using Collarbell.Api.Modules.Documents;
using Collarbell.Api.Modules.Identity;
using Collarbell.Api.Modules.Notifications;
using Collarbell.Api.Modules.Observe;
using Collarbell.Api.Modules.Pets;
using Collarbell.Api.Modules.Routines;
using Collarbell.Api.Modules.Supplies;
using Microsoft.EntityFrameworkCore;

namespace Collarbell.Api.Infrastructure.Persistence;

/// <summary>One context for the modular monolith; every module keeps its tables in its own schema.</summary>
public sealed class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<User> Users => Set<User>();
    public DbSet<Household> Households => Set<Household>();
    public DbSet<HouseholdMember> HouseholdMembers => Set<HouseholdMember>();
    public DbSet<HouseholdInvite> HouseholdInvites => Set<HouseholdInvite>();
    public DbSet<DeletedAccount> DeletedAccounts => Set<DeletedAccount>();
    public DbSet<Pet> Pets => Set<Pet>();
    public DbSet<PetPassport> PetPassports => Set<PetPassport>();
    public DbSet<WeightEntry> WeightEntries => Set<WeightEntry>();
    public DbSet<StoredFile> StoredFiles => Set<StoredFile>();
    public DbSet<StorageDeletion> StorageDeletions => Set<StorageDeletion>();
    public DbSet<Document> Documents => Set<Document>();
    public DbSet<CarePlan> CarePlans => Set<CarePlan>();
    public DbSet<CareRecord> CareRecords => Set<CareRecord>();
    public DbSet<AiImport> AiImports => Set<AiImport>();
    public DbSet<AiUsage> AiUsage => Set<AiUsage>();
    public DbSet<Device> Devices => Set<Device>();
    public DbSet<NotificationPreference> NotificationPreferences => Set<NotificationPreference>();
    public DbSet<Reminder> Reminders => Set<Reminder>();
    public DbSet<Routine> Routines => Set<Routine>();
    public DbSet<RoutineCompletion> RoutineCompletions => Set<RoutineCompletion>();
    public DbSet<Appointment> Appointments => Set<Appointment>();
    public DbSet<SupplyItem> SupplyItems => Set<SupplyItem>();
    public DbSet<StockEvent> StockEvents => Set<StockEvent>();
    public DbSet<Product> Products => Set<Product>();
    public DbSet<RequestRecord> Requests => Set<RequestRecord>();
    public DbSet<AppEvent> AppEvents => Set<AppEvent>();
    public DbSet<AlertRecord> Alerts => Set<AlertRecord>();
    public DbSet<HouseholdPlan> HouseholdPlans => Set<HouseholdPlan>();
    public DbSet<AiPhotoCharge> AiPhotoCharges => Set<AiPhotoCharge>();

    protected override void OnModelCreating(ModelBuilder modelBuilder) =>
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);
}
