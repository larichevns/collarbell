using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Collarbell.Api.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AccountDeletion : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "fk_completions_users_done_by",
                schema: "routines",
                table: "completions");

            migrationBuilder.AlterColumn<Guid>(
                name: "done_by",
                schema: "routines",
                table: "completions",
                type: "uuid",
                nullable: true,
                oldClrType: typeof(Guid),
                oldType: "uuid");

            migrationBuilder.CreateTable(
                name: "deleted_accounts",
                schema: "identity",
                columns: table => new
                {
                    auth_subject = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    deleted_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    sign_in_deleted_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    attempts = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_deleted_accounts", x => x.auth_subject);
                });

            migrationBuilder.AddForeignKey(
                name: "fk_completions_users_done_by",
                schema: "routines",
                table: "completions",
                column: "done_by",
                principalSchema: "identity",
                principalTable: "users",
                principalColumn: "id",
                onDelete: ReferentialAction.SetNull);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "fk_completions_users_done_by",
                schema: "routines",
                table: "completions");

            migrationBuilder.DropTable(
                name: "deleted_accounts",
                schema: "identity");

            migrationBuilder.AlterColumn<Guid>(
                name: "done_by",
                schema: "routines",
                table: "completions",
                type: "uuid",
                nullable: false,
                defaultValue: new Guid("00000000-0000-0000-0000-000000000000"),
                oldClrType: typeof(Guid),
                oldType: "uuid",
                oldNullable: true);

            migrationBuilder.AddForeignKey(
                name: "fk_completions_users_done_by",
                schema: "routines",
                table: "completions",
                column: "done_by",
                principalSchema: "identity",
                principalTable: "users",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);
        }
    }
}
