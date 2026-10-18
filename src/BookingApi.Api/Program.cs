using BookingApi.Api.Errors;
using BookingApi.Api.Health;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOpenApi(options => options.AddHealthDocumentation());
builder.Services.AddProblemDetailsErrors();
builder.Services.AddHealth();

var app = builder.Build();

app.UseProblemDetailsErrors();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseHttpsRedirection();

app.MapHealth();

app.Run();
