using Collarbell.Api.Modules.Pets;

namespace Collarbell.Api.Modules.Care;

/// <summary>
/// A ready-made plan: kind, title and a default interval. Every value is a starting point the user (or the
/// vet) can change. <see cref="Species"/> null means any species.
/// </summary>
public sealed record CarePreset(
    string Code,
    Species? Species,
    CareKind Kind,
    string Title,
    int? IntervalValue,
    IntervalUnit? IntervalUnit,
    List<VaccineTarget> Targets,
    bool DogOnly,
    string? Note);

/// <summary>
/// The preset catalog (spec, appendix A: WSAVA, AAHA, ESCCAP 2025, product labels). It lives in code, not
/// in the database: it changes with the app, and a test checks it. The app shows titles in the user's
/// language by <see cref="CarePreset.Code"/>; the English title here is the fallback.
/// </summary>
public static class CarePresets
{
    private static readonly List<VaccineTarget> None = [];

    public static readonly IReadOnlyList<CarePreset> All =
    [
        // Cats: vaccinations (A.1)
        Cat("cat-fvrcp", CareKind.Vaccination, "FVRCP (panleukopenia, herpes, calici)", 1, IntervalUnit.Year,
            [VaccineTarget.Fpv, VaccineTarget.Fhv1, VaccineTarget.Fcv],
            "After the kitten series and the 6-month booster. Low-risk indoor cats: every 3 years."),
        Cat("cat-fvrcp-kitten", CareKind.Vaccination, "FVRCP kitten series", 4, IntervalUnit.Week,
            [VaccineTarget.Fpv, VaccineTarget.Fhv1, VaccineTarget.Fcv],
            "From 6–8 weeks every 3–4 weeks until 16–20 weeks, then the yearly plan."),
        Cat("cat-rabies", CareKind.Vaccination, "Rabies", 1, IntervalUnit.Year, [VaccineTarget.Rabies],
            "The vaccine label says 1 or 3 years: use its \"valid until\" date."),
        Cat("cat-felv", CareKind.Vaccination, "Feline leukaemia (FeLV)", 1, IntervalUnit.Year, [VaccineTarget.Felv],
            "Test first. Two doses 3–4 weeks apart, then yearly for cats that go outside."),
        Cat("cat-chlamydia", CareKind.Vaccination, "Chlamydia", 1, IntervalUnit.Year, [VaccineTarget.Chlamydia],
            "Only when the cat is at risk."),

        // Cats: deworming (A.2, ESCCAP 2025)
        Cat("cat-deworm", CareKind.Deworming, "Deworming", 3, IntervalUnit.Month, None,
            "When the risk is unknown: at least 4 times a year."),
        Cat("cat-deworm-indoor", CareKind.Deworming, "Deworming, indoor cat", 6, IntervalUnit.Month, None,
            "Indoor cats: 1–2 times a year."),
        Cat("cat-deworm-outdoor", CareKind.Deworming, "Deworming, cat that hunts", 1, IntervalUnit.Month, None,
            "Cats that go out and hunt: 4–12 times a year."),
        Cat("cat-deworm-kitten", CareKind.Deworming, "Deworming, kitten", 2, IntervalUnit.Week, None,
            "From 3 weeks every 2 weeks until weaning, then monthly until 6 months."),

        // Cats: fleas and ticks (A.3)
        Cat("cat-fleatick-monthly", CareKind.FleaTick, "Fleas and ticks, monthly", 1, IntervalUnit.Month, None,
            "Monthly products such as Frontline, Advantage or Revolution."),
        Cat("cat-bravecto", CareKind.FleaTick, "Bravecto", 12, IntervalUnit.Week, None,
            "Some ticks: 8 weeks."),
        Cat("cat-bravecto-plus", CareKind.FleaTick, "Bravecto Plus (also worms and heartworm)", 12, IntervalUnit.Week, None,
            "US label: 2 months."),
        Cat("cat-seresto", CareKind.FleaTick, "Seresto collar", 8, IntervalUnit.Month, None, null),

        // Cats: routine care (A.5)
        Cat("cat-exam", CareKind.VetExam, "Check-up", 1, IntervalUnit.Year, None, "From 10 years old: every 6 months."),
        Cat("cat-dental", CareKind.Dental, "Dental check", 1, IntervalUnit.Year, None, null),
        Cat("cat-nails", CareKind.Grooming, "Nail trim", 3, IntervalUnit.Week, None, null),

        // Dogs: vaccinations (A.1)
        Dog("dog-dhpp", CareKind.Vaccination, "DHPP (distemper, hepatitis, parvo, parainfluenza)", 3, IntervalUnit.Year,
            [VaccineTarget.Cdv, VaccineTarget.Cav2, VaccineTarget.Cpv2, VaccineTarget.Cpiv],
            "After the puppy series and the booster at about 6 months or 1 year."),
        Dog("dog-dhpp-puppy", CareKind.Vaccination, "DHPP puppy series", 3, IntervalUnit.Week,
            [VaccineTarget.Cdv, VaccineTarget.Cav2, VaccineTarget.Cpv2, VaccineTarget.Cpiv],
            "From 6–8 weeks every 2–4 weeks until at least 16 weeks, then the 3-year plan."),
        Dog("dog-rabies", CareKind.Vaccination, "Rabies", 1, IntervalUnit.Year, [VaccineTarget.Rabies],
            "The vaccine label says 1 or 3 years: use its \"valid until\" date."),
        Dog("dog-lepto", CareKind.Vaccination, "Leptospirosis", 1, IntervalUnit.Year, [VaccineTarget.Lepto],
            "First 2 doses 2–4 weeks apart, then yearly."),
        Dog("dog-kennel-cough", CareKind.Vaccination, "Kennel cough", 1, IntervalUnit.Year,
            [VaccineTarget.Bordetella, VaccineTarget.Cpiv], "For dogs that meet other dogs: boarding, training, shows."),
        Dog("dog-lyme", CareKind.Vaccination, "Lyme disease", 1, IntervalUnit.Year, [VaccineTarget.Lyme],
            "Where ticks carry Lyme disease."),
        Dog("dog-leishmania", CareKind.Vaccination, "Leishmaniasis", 1, IntervalUnit.Year, [VaccineTarget.Leishmania],
            "Southern Europe."),

        // Dogs: deworming (A.2, ESCCAP 2025)
        Dog("dog-deworm", CareKind.Deworming, "Deworming", 3, IntervalUnit.Month, None,
            "When the risk is unknown: at least 4 times a year."),
        Dog("dog-deworm-indoor", CareKind.Deworming, "Deworming, mostly indoors", 6, IntervalUnit.Month, None,
            "Dogs that stay home: 1–2 times a year."),
        Dog("dog-deworm-high", CareKind.Deworming, "Deworming, high risk", 1, IntervalUnit.Month, None,
            "Dogs that hunt, eat snails or grass, or get raw meat: up to 12 times a year."),
        Dog("dog-deworm-puppy", CareKind.Deworming, "Deworming, puppy", 2, IntervalUnit.Week, None,
            "From 14 days every 2 weeks until weaning, then monthly until 6 months."),

        // Dogs: fleas, ticks, heartworm (A.3)
        Dog("dog-fleatick-monthly", CareKind.FleaTick, "Fleas and ticks, monthly", 1, IntervalUnit.Month, None,
            "Monthly products such as NexGard, Simparica, Credelio or Frontline."),
        Dog("dog-bravecto", CareKind.FleaTick, "Bravecto", 12, IntervalUnit.Week, None, "Some ticks: 8 weeks."),
        Dog("dog-seresto", CareKind.FleaTick, "Seresto collar", 8, IntervalUnit.Month, None, null),
        new("dog-advantix", Species.Dog, CareKind.FleaTick, "K9 Advantix", 1, IntervalUnit.Month, None, DogOnly: true,
            "Contains permethrin, which is toxic to cats. Never use it on a cat."),
        Dog("dog-heartworm", CareKind.Heartworm, "Heartworm prevention", 1, IntervalUnit.Month, None, null),

        // Dogs: before travel (A.4) and routine care (A.5)
        Dog("dog-echinococcus", CareKind.Echinococcus, "Tapeworm treatment before travel", null, null, None,
            "Finland, Ireland, Malta, Northern Ireland, Norway, the UK: 24–120 hours before entry. The vet writes the date and time."),
        Dog("dog-exam", CareKind.VetExam, "Check-up", 1, IntervalUnit.Year, None, "Senior dogs: every 6 months."),
        Dog("dog-dental", CareKind.Dental, "Dental check", 1, IntervalUnit.Year, None, null),
        Dog("dog-nails", CareKind.Grooming, "Nail trim", 4, IntervalUnit.Week, None, null),
    ];

    public static CarePreset? Find(string code) => All.FirstOrDefault(p => p.Code == code);

    /// <summary>Presets that suit the species: its own and those for any species.</summary>
    public static IEnumerable<CarePreset> For(Species species) =>
        All.Where(p => p.Species is null || p.Species == species);

    private static CarePreset Cat(
        string code, CareKind kind, string title, int? value, IntervalUnit? unit, List<VaccineTarget> targets, string? note) =>
        new(code, Species.Cat, kind, title, value, unit, targets, DogOnly: false, note);

    private static CarePreset Dog(
        string code, CareKind kind, string title, int? value, IntervalUnit? unit, List<VaccineTarget> targets, string? note) =>
        new(code, Species.Dog, kind, title, value, unit, targets, DogOnly: false, note);
}
