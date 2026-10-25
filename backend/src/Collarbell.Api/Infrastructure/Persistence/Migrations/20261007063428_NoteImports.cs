using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Collarbell.Api.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class NoteImports : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "text",
                schema: "ai",
                table: "imports",
                type: "character varying(1000)",
                maxLength: 1000,
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "text",
                schema: "ai",
                table: "imports");
        }
    }
}
