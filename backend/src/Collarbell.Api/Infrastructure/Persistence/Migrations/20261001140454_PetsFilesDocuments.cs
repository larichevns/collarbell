using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Collarbell.Api.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class PetsFilesDocuments : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.EnsureSchema(
                name: "documents");

            migrationBuilder.AddColumn<Guid>(
                name: "photo_file_id",
                schema: "pets",
                table: "pets",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "documents",
                schema: "documents",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    household_id = table.Column<Guid>(type: "uuid", nullable: false),
                    pet_id = table.Column<Guid>(type: "uuid", nullable: true),
                    type = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    title = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    document_date = table.Column<DateOnly>(type: "date", nullable: true),
                    notes = table.Column<string>(type: "character varying(2000)", maxLength: 2000, nullable: true),
                    created_by = table.Column<Guid>(type: "uuid", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_documents", x => x.id);
                    table.ForeignKey(
                        name: "fk_documents_households_household_id",
                        column: x => x.household_id,
                        principalSchema: "identity",
                        principalTable: "households",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_documents_pets_pet_id",
                        column: x => x.pet_id,
                        principalSchema: "pets",
                        principalTable: "pets",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "pet_identifiers",
                schema: "pets",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    pet_id = table.Column<Guid>(type: "uuid", nullable: false),
                    type = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    code = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false),
                    raw_code = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false),
                    applied_on = table.Column<DateOnly>(type: "date", nullable: true),
                    read_on = table.Column<DateOnly>(type: "date", nullable: true),
                    location = table.Column<string>(type: "character varying(60)", maxLength: 60, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_pet_identifiers", x => x.id);
                    table.ForeignKey(
                        name: "fk_pet_identifiers_pets_pet_id",
                        column: x => x.pet_id,
                        principalSchema: "pets",
                        principalTable: "pets",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "pet_passports",
                schema: "pets",
                columns: table => new
                {
                    pet_id = table.Column<Guid>(type: "uuid", nullable: false),
                    model = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: true),
                    passport_number = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: true),
                    issuing_country = table.Column<string>(type: "character varying(2)", maxLength: 2, nullable: true),
                    issued_on = table.Column<DateOnly>(type: "date", nullable: true),
                    notes = table.Column<string>(type: "character varying(2000)", maxLength: 2000, nullable: true),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    issuer = table.Column<string>(type: "jsonb", nullable: true),
                    owners = table.Column<string>(type: "jsonb", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_pet_passports", x => x.pet_id);
                    table.ForeignKey(
                        name: "fk_pet_passports_pets_pet_id",
                        column: x => x.pet_id,
                        principalSchema: "pets",
                        principalTable: "pets",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "storage_deletions",
                schema: "documents",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    key = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    attempts = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_storage_deletions", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "stored_files",
                schema: "documents",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    household_id = table.Column<Guid>(type: "uuid", nullable: false),
                    storage_key = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    thumbnail_key = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    content_type = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    size_bytes = table.Column<long>(type: "bigint", nullable: false),
                    sha256 = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    width = table.Column<int>(type: "integer", nullable: true),
                    height = table.Column<int>(type: "integer", nullable: true),
                    created_by = table.Column<Guid>(type: "uuid", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    attached_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_stored_files", x => x.id);
                    table.ForeignKey(
                        name: "fk_stored_files_households_household_id",
                        column: x => x.household_id,
                        principalSchema: "identity",
                        principalTable: "households",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "document_pages",
                schema: "documents",
                columns: table => new
                {
                    file_id = table.Column<Guid>(type: "uuid", nullable: false),
                    document_id = table.Column<Guid>(type: "uuid", nullable: false),
                    page_no = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_document_pages", x => x.file_id);
                    table.ForeignKey(
                        name: "fk_document_pages_documents_document_id",
                        column: x => x.document_id,
                        principalSchema: "documents",
                        principalTable: "documents",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_document_pages_stored_files_file_id",
                        column: x => x.file_id,
                        principalSchema: "documents",
                        principalTable: "stored_files",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "ix_pets_photo_file_id",
                schema: "pets",
                table: "pets",
                column: "photo_file_id",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_document_pages_document_id",
                schema: "documents",
                table: "document_pages",
                column: "document_id");

            migrationBuilder.CreateIndex(
                name: "ix_documents_household_id_pet_id",
                schema: "documents",
                table: "documents",
                columns: new[] { "household_id", "pet_id" });

            migrationBuilder.CreateIndex(
                name: "ix_documents_pet_id",
                schema: "documents",
                table: "documents",
                column: "pet_id");

            migrationBuilder.CreateIndex(
                name: "ix_pet_identifiers_pet_id",
                schema: "pets",
                table: "pet_identifiers",
                column: "pet_id");

            migrationBuilder.CreateIndex(
                name: "ix_stored_files_created_at",
                schema: "documents",
                table: "stored_files",
                column: "created_at",
                filter: "attached_at IS NULL");

            migrationBuilder.CreateIndex(
                name: "ix_stored_files_household_id",
                schema: "documents",
                table: "stored_files",
                column: "household_id");

            migrationBuilder.AddForeignKey(
                name: "fk_pets_stored_files_photo_file_id",
                schema: "pets",
                table: "pets",
                column: "photo_file_id",
                principalSchema: "documents",
                principalTable: "stored_files",
                principalColumn: "id",
                onDelete: ReferentialAction.SetNull);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "fk_pets_stored_files_photo_file_id",
                schema: "pets",
                table: "pets");

            migrationBuilder.DropTable(
                name: "document_pages",
                schema: "documents");

            migrationBuilder.DropTable(
                name: "pet_identifiers",
                schema: "pets");

            migrationBuilder.DropTable(
                name: "pet_passports",
                schema: "pets");

            migrationBuilder.DropTable(
                name: "storage_deletions",
                schema: "documents");

            migrationBuilder.DropTable(
                name: "documents",
                schema: "documents");

            migrationBuilder.DropTable(
                name: "stored_files",
                schema: "documents");

            migrationBuilder.DropIndex(
                name: "ix_pets_photo_file_id",
                schema: "pets",
                table: "pets");

            migrationBuilder.DropColumn(
                name: "photo_file_id",
                schema: "pets",
                table: "pets");
        }
    }
}
