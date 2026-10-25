using System;
using System.Collections.Generic;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Collarbell.Api.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class Care : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.EnsureSchema(
                name: "care");

            migrationBuilder.CreateTable(
                name: "care_plans",
                schema: "care",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    household_id = table.Column<Guid>(type: "uuid", nullable: false),
                    pet_id = table.Column<Guid>(type: "uuid", nullable: false),
                    kind = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: false),
                    title = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    interval_value = table.Column<int>(type: "integer", nullable: true),
                    interval_unit = table.Column<string>(type: "character varying(8)", maxLength: 8, nullable: true),
                    next_due_on = table.Column<DateOnly>(type: "date", nullable: false),
                    remind_offsets_days = table.Column<List<int>>(type: "integer[]", nullable: false),
                    default_product = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    targets = table.Column<string[]>(type: "text[]", nullable: false),
                    preset_code = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: true),
                    notes = table.Column<string>(type: "character varying(2000)", maxLength: 2000, nullable: true),
                    active = table.Column<bool>(type: "boolean", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_care_plans", x => x.id);
                    table.ForeignKey(
                        name: "fk_care_plans_households_household_id",
                        column: x => x.household_id,
                        principalSchema: "identity",
                        principalTable: "households",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_care_plans_pets_pet_id",
                        column: x => x.pet_id,
                        principalSchema: "pets",
                        principalTable: "pets",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "care_records",
                schema: "care",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    household_id = table.Column<Guid>(type: "uuid", nullable: false),
                    pet_id = table.Column<Guid>(type: "uuid", nullable: false),
                    plan_id = table.Column<Guid>(type: "uuid", nullable: true),
                    kind = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: false),
                    performed_on = table.Column<DateOnly>(type: "date", nullable: false),
                    performed_time = table.Column<TimeOnly>(type: "time without time zone", nullable: true),
                    title = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    product = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    manufacturer = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    batch_number = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                    valid_from = table.Column<DateOnly>(type: "date", nullable: true),
                    valid_until = table.Column<DateOnly>(type: "date", nullable: true),
                    targets = table.Column<string[]>(type: "text[]", nullable: false),
                    clinic = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    veterinarian = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    weight_kg = table.Column<decimal>(type: "numeric(6,2)", precision: 6, scale: 2, nullable: true),
                    notes = table.Column<string>(type: "character varying(2000)", maxLength: 2000, nullable: true),
                    source = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    created_by = table.Column<Guid>(type: "uuid", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    details = table.Column<string>(type: "jsonb", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_care_records", x => x.id);
                    table.ForeignKey(
                        name: "fk_care_records_care_plans_plan_id",
                        column: x => x.plan_id,
                        principalSchema: "care",
                        principalTable: "care_plans",
                        principalColumn: "id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "fk_care_records_households_household_id",
                        column: x => x.household_id,
                        principalSchema: "identity",
                        principalTable: "households",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_care_records_pets_pet_id",
                        column: x => x.pet_id,
                        principalSchema: "pets",
                        principalTable: "pets",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "care_record_files",
                schema: "care",
                columns: table => new
                {
                    file_id = table.Column<Guid>(type: "uuid", nullable: false),
                    care_record_id = table.Column<Guid>(type: "uuid", nullable: false),
                    position = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_care_record_files", x => x.file_id);
                    table.ForeignKey(
                        name: "fk_care_record_files_care_records_care_record_id",
                        column: x => x.care_record_id,
                        principalSchema: "care",
                        principalTable: "care_records",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_care_record_files_stored_files_file_id",
                        column: x => x.file_id,
                        principalSchema: "documents",
                        principalTable: "stored_files",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "ix_care_plans_household_id_active_next_due_on",
                schema: "care",
                table: "care_plans",
                columns: new[] { "household_id", "active", "next_due_on" });

            migrationBuilder.CreateIndex(
                name: "ix_care_plans_pet_id",
                schema: "care",
                table: "care_plans",
                column: "pet_id");

            migrationBuilder.CreateIndex(
                name: "ix_care_record_files_care_record_id",
                schema: "care",
                table: "care_record_files",
                column: "care_record_id");

            migrationBuilder.CreateIndex(
                name: "ix_care_records_household_id",
                schema: "care",
                table: "care_records",
                column: "household_id");

            migrationBuilder.CreateIndex(
                name: "ix_care_records_pet_id_performed_on",
                schema: "care",
                table: "care_records",
                columns: new[] { "pet_id", "performed_on" });

            migrationBuilder.CreateIndex(
                name: "ix_care_records_plan_id",
                schema: "care",
                table: "care_records",
                column: "plan_id");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "care_record_files",
                schema: "care");

            migrationBuilder.DropTable(
                name: "care_records",
                schema: "care");

            migrationBuilder.DropTable(
                name: "care_plans",
                schema: "care");
        }
    }
}
