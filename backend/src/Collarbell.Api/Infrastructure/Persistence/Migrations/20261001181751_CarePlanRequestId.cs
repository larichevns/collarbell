using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Collarbell.Api.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class CarePlanRequestId : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "client_request_id",
                schema: "care",
                table: "care_plans",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "ix_care_plans_household_id_client_request_id",
                schema: "care",
                table: "care_plans",
                columns: new[] { "household_id", "client_request_id" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "ix_care_plans_household_id_client_request_id",
                schema: "care",
                table: "care_plans");

            migrationBuilder.DropColumn(
                name: "client_request_id",
                schema: "care",
                table: "care_plans");
        }
    }
}
