using BookingApi.Api.Errors;
using BookingApi.Api.Health;
using BookingApi.Infrastructure;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOpenApi(options => options.AddHealthDocumentation());
builder.Services.AddProblemDetailsErrors();
builder.Services.AddHealth();
builder.Services.AddInfrastructure();

var app = builder.Build();

app.UseProblemDetailsErrors();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseHttpsRedirection();

app.MapHealth();

app.Run();
