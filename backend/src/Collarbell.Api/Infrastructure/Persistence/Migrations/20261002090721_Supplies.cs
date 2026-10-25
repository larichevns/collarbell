using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Collarbell.Api.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class Supplies : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.EnsureSchema(
                name: "supplies");

            migrationBuilder.AddColumn<Guid>(
                name: "supply_item_id",
                schema: "routines",
                table: "routines",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "items",
                schema: "supplies",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    household_id = table.Column<Guid>(type: "uuid", nullable: false),
                    name = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    brand = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    barcode = table.Column<string>(type: "character varying(14)", maxLength: 14, nullable: true),
                    category = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    unit = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    package_size = table.Column<decimal>(type: "numeric(12,3)", precision: 12, scale: 3, nullable: false),
                    kcal_per_kg = table.Column<int>(type: "integer", nullable: true),
                    usage_mode = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    manual_daily_usage = table.Column<decimal>(type: "numeric(16,6)", precision: 16, scale: 6, nullable: true),
                    lead_time_days = table.Column<int>(type: "integer", nullable: false),
                    store_url = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    notes = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    active = table.Column<bool>(type: "boolean", nullable: false),
                    client_request_id = table.Column<Guid>(type: "uuid", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_items", x => x.id);
                    table.ForeignKey(
                        name: "fk_items_households_household_id",
                        column: x => x.household_id,
                        principalSchema: "identity",
                        principalTable: "households",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "products",
                schema: "supplies",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    barcode = table.Column<string>(type: "character varying(14)", maxLength: 14, nullable: false),
                    name = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    brand = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    category = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    unit = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    package_size = table.Column<decimal>(type: "numeric(12,3)", precision: 12, scale: 3, nullable: false),
                    kcal_per_kg = table.Column<int>(type: "integer", nullable: true),
                    source = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    confirmed_count = table.Column<int>(type: "integer", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_products", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "stock_events",
                schema: "supplies",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    household_id = table.Column<Guid>(type: "uuid", nullable: false),
                    supply_item_id = table.Column<Guid>(type: "uuid", nullable: false),
                    kind = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    quantity = table.Column<decimal>(type: "numeric(14,3)", precision: 14, scale: 3, nullable: false),
                    at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<Guid>(type: "uuid", nullable: false),
                    client_request_id = table.Column<Guid>(type: "uuid", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_stock_events", x => x.id);
                    table.ForeignKey(
                        name: "fk_stock_events_households_household_id",
                        column: x => x.household_id,
                        principalSchema: "identity",
                        principalTable: "households",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_stock_events_supply_items_supply_item_id",
                        column: x => x.supply_item_id,
                        principalSchema: "supplies",
                        principalTable: "items",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_stock_events_users_created_by",
                        column: x => x.created_by,
                        principalSchema: "identity",
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "ix_routines_supply_item_id",
                schema: "routines",
                table: "routines",
                column: "supply_item_id");

            migrationBuilder.CreateIndex(
                name: "ix_items_household_id_active",
                schema: "supplies",
                table: "items",
                columns: new[] { "household_id", "active" });

            migrationBuilder.CreateIndex(
                name: "ix_items_household_id_barcode",
                schema: "supplies",
                table: "items",
                columns: new[] { "household_id", "barcode" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_items_household_id_client_request_id",
                schema: "supplies",
                table: "items",
                columns: new[] { "household_id", "client_request_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_products_barcode",
                schema: "supplies",
                table: "products",
                column: "barcode",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_stock_events_created_by",
                schema: "supplies",
                table: "stock_events",
                column: "created_by");

            migrationBuilder.CreateIndex(
                name: "ix_stock_events_household_id_client_request_id",
                schema: "supplies",
                table: "stock_events",
                columns: new[] { "household_id", "client_request_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_stock_events_supply_item_id_at",
                schema: "supplies",
                table: "stock_events",
                columns: new[] { "supply_item_id", "at" });

            migrationBuilder.AddForeignKey(
                name: "fk_routines_supply_items_supply_item_id",
                schema: "routines",
                table: "routines",
                column: "supply_item_id",
                principalSchema: "supplies",
                principalTable: "items",
                principalColumn: "id",
                onDelete: ReferentialAction.SetNull);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "fk_routines_supply_items_supply_item_id",
                schema: "routines",
                table: "routines");

            migrationBuilder.DropTable(
                name: "products",
                schema: "supplies");

            migrationBuilder.DropTable(
                name: "stock_events",
                schema: "supplies");

            migrationBuilder.DropTable(
                name: "items",
                schema: "supplies");

            migrationBuilder.DropIndex(
                name: "ix_routines_supply_item_id",
                schema: "routines",
                table: "routines");

            migrationBuilder.DropColumn(
                name: "supply_item_id",
                schema: "routines",
                table: "routines");
        }
    }
}
