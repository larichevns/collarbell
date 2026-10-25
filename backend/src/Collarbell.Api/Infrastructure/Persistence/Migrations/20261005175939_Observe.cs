using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace Collarbell.Api.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class Observe : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.EnsureSchema(
                name: "observe");

            migrationBuilder.AddColumn<bool>(
                name: "is_admin",
                schema: "identity",
                table: "users",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.CreateTable(
                name: "alerts",
                schema: "observe",
                columns: table => new
                {
                    kind = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false),
                    text = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                    sent_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_alerts", x => x.kind);
                });

            migrationBuilder.CreateTable(
                name: "app_events",
                schema: "observe",
                columns: table => new
                {
                    id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityAlwaysColumn),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    household_id = table.Column<Guid>(type: "uuid", nullable: true),
                    session = table.Column<Guid>(type: "uuid", nullable: false),
                    at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    kind = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    name = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    detail = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    app_version = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: true),
                    received_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_app_events", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "requests",
                schema: "observe",
                columns: table => new
                {
                    id = table.Column<long>(type: "bigint", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityAlwaysColumn),
                    at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    user_id = table.Column<Guid>(type: "uuid", nullable: true),
                    household_id = table.Column<Guid>(type: "uuid", nullable: true),
                    method = table.Column<string>(type: "character varying(8)", maxLength: 8, nullable: false),
                    path = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: false),
                    status = table.Column<int>(type: "integer", nullable: false),
                    duration_ms = table.Column<int>(type: "integer", nullable: false),
                    session = table.Column<Guid>(type: "uuid", nullable: true),
                    app_version = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_requests", x => x.id);
                });

            migrationBuilder.CreateIndex(
                name: "ix_app_events_kind_at",
                schema: "observe",
                table: "app_events",
                columns: new[] { "kind", "at" });

            migrationBuilder.CreateIndex(
                name: "ix_app_events_received_at",
                schema: "observe",
                table: "app_events",
                column: "received_at");

            migrationBuilder.CreateIndex(
                name: "ix_app_events_user_id_at",
                schema: "observe",
                table: "app_events",
                columns: new[] { "user_id", "at" });

            migrationBuilder.CreateIndex(
                name: "ix_app_events_user_id_received_at",
                schema: "observe",
                table: "app_events",
                columns: new[] { "user_id", "received_at" });

            migrationBuilder.CreateIndex(
                name: "ix_requests_at",
                schema: "observe",
                table: "requests",
                column: "at");

            migrationBuilder.CreateIndex(
                name: "ix_requests_status_at",
                schema: "observe",
                table: "requests",
                columns: new[] { "status", "at" });

            migrationBuilder.CreateIndex(
                name: "ix_requests_user_id_at",
                schema: "observe",
                table: "requests",
                columns: new[] { "user_id", "at" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "alerts",
                schema: "observe");

            migrationBuilder.DropTable(
                name: "app_events",
                schema: "observe");

            migrationBuilder.DropTable(
                name: "requests",
                schema: "observe");

            migrationBuilder.DropColumn(
                name: "is_admin",
                schema: "identity",
                table: "users");
        }
    }
}
