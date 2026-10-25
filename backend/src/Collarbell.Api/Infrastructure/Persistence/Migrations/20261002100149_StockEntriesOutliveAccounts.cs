using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Collarbell.Api.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class StockEntriesOutliveAccounts : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "fk_stock_events_users_created_by",
                schema: "supplies",
                table: "stock_events");

            migrationBuilder.AlterColumn<Guid>(
                name: "created_by",
                schema: "supplies",
                table: "stock_events",
                type: "uuid",
                nullable: true,
                oldClrType: typeof(Guid),
                oldType: "uuid");

            migrationBuilder.AddForeignKey(
                name: "fk_stock_events_users_created_by",
                schema: "supplies",
                table: "stock_events",
                column: "created_by",
                principalSchema: "identity",
                principalTable: "users",
                principalColumn: "id",
                onDelete: ReferentialAction.SetNull);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "fk_stock_events_users_created_by",
                schema: "supplies",
                table: "stock_events");

            migrationBuilder.AlterColumn<Guid>(
                name: "created_by",
                schema: "supplies",
                table: "stock_events",
                type: "uuid",
                nullable: false,
                defaultValue: new Guid("00000000-0000-0000-0000-000000000000"),
                oldClrType: typeof(Guid),
                oldType: "uuid",
                oldNullable: true);

            migrationBuilder.AddForeignKey(
                name: "fk_stock_events_users_created_by",
                schema: "supplies",
                table: "stock_events",
                column: "created_by",
                principalSchema: "identity",
                principalTable: "users",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);
        }
    }
}
