using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Collarbell.Api.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class WeightLog : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "weight_entries",
                schema: "pets",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    household_id = table.Column<Guid>(type: "uuid", nullable: false),
                    pet_id = table.Column<Guid>(type: "uuid", nullable: false),
                    measured_on = table.Column<DateOnly>(type: "date", nullable: false),
                    weight_kg = table.Column<decimal>(type: "numeric(6,3)", precision: 6, scale: 3, nullable: false),
                    bcs = table.Column<int>(type: "integer", nullable: true),
                    bcs_scale = table.Column<int>(type: "integer", nullable: true),
                    note = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    created_by = table.Column<Guid>(type: "uuid", nullable: true),
                    client_request_id = table.Column<Guid>(type: "uuid", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_weight_entries", x => x.id);
                    table.ForeignKey(
                        name: "fk_weight_entries_households_household_id",
                        column: x => x.household_id,
                        principalSchema: "identity",
                        principalTable: "households",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_weight_entries_pets_pet_id",
                        column: x => x.pet_id,
                        principalSchema: "pets",
                        principalTable: "pets",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_weight_entries_users_created_by",
                        column: x => x.created_by,
                        principalSchema: "identity",
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateIndex(
                name: "ix_weight_entries_created_by",
                schema: "pets",
                table: "weight_entries",
                column: "created_by");

            migrationBuilder.CreateIndex(
                name: "ix_weight_entries_household_id_client_request_id",
                schema: "pets",
                table: "weight_entries",
                columns: new[] { "household_id", "client_request_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_weight_entries_pet_id_measured_on",
                schema: "pets",
                table: "weight_entries",
                columns: new[] { "pet_id", "measured_on" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "weight_entries",
                schema: "pets");
        }
    }
}
