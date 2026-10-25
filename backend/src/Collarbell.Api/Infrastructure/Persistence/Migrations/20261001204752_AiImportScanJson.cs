using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Collarbell.Api.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AiImportScanJson : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.RenameColumn(
                name: "draft_json",
                schema: "ai",
                table: "imports",
                newName: "scan_json");

            // Rows written before held a built draft, not the model's answer. Unsaved ones are dropped (test data).
            migrationBuilder.Sql("UPDATE ai.imports SET scan_json = NULL, status = 'Discarded' WHERE status = 'Ready';");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.RenameColumn(
                name: "scan_json",
                schema: "ai",
                table: "imports",
                newName: "draft_json");
        }
    }
}
