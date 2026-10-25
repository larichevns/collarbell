using System;
using System.Collections.Generic;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Collarbell.Api.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AiImports : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.EnsureSchema(
                name: "ai");

            migrationBuilder.CreateTable(
                name: "imports",
                schema: "ai",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    household_id = table.Column<Guid>(type: "uuid", nullable: false),
                    pet_id = table.Column<Guid>(type: "uuid", nullable: false),
                    source = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: false),
                    file_ids = table.Column<List<Guid>>(type: "uuid[]", nullable: false),
                    status = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    draft_json = table.Column<string>(type: "jsonb", nullable: true),
                    error = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: true),
                    provider = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: true),
                    model = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    prompt_version = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false),
                    result_json = table.Column<string>(type: "jsonb", nullable: true),
                    client_request_id = table.Column<Guid>(type: "uuid", nullable: true),
                    created_by = table.Column<Guid>(type: "uuid", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    started_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    completed_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    applied_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_imports", x => x.id);
                    table.ForeignKey(
                        name: "fk_imports_households_household_id",
                        column: x => x.household_id,
                        principalSchema: "identity",
                        principalTable: "households",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_imports_pets_pet_id",
                        column: x => x.pet_id,
                        principalSchema: "pets",
                        principalTable: "pets",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "usage",
                schema: "ai",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    household_id = table.Column<Guid>(type: "uuid", nullable: false),
                    feature = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false),
                    provider = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: false),
                    model = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    input_tokens = table.Column<long>(type: "bigint", nullable: true),
                    output_tokens = table.Column<long>(type: "bigint", nullable: true),
                    latency_ms = table.Column<int>(type: "integer", nullable: false),
                    success = table.Column<bool>(type: "boolean", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_usage", x => x.id);
                    table.ForeignKey(
                        name: "fk_usage_households_household_id",
                        column: x => x.household_id,
                        principalSchema: "identity",
                        principalTable: "households",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "ix_imports_household_id_client_request_id",
                schema: "ai",
                table: "imports",
                columns: new[] { "household_id", "client_request_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_imports_pet_id_created_at",
                schema: "ai",
                table: "imports",
                columns: new[] { "pet_id", "created_at" });

            migrationBuilder.CreateIndex(
                name: "ix_imports_status",
                schema: "ai",
                table: "imports",
                column: "status",
                filter: "status IN ('Queued', 'Processing')");

            migrationBuilder.CreateIndex(
                name: "ix_usage_household_id_created_at",
                schema: "ai",
                table: "usage",
                columns: new[] { "household_id", "created_at" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "imports",
                schema: "ai");

            migrationBuilder.DropTable(
                name: "usage",
                schema: "ai");
        }
    }
}
