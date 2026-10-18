using BookingApi.Api.Errors;
using BookingApi.Api.Features.Resources;
using BookingApi.Api.Health;
using BookingApi.Application.Resources;
using BookingApi.Infrastructure;
using Microsoft.AspNetCore.Http;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOpenApi(options => options.AddHealthDocumentation());
builder.Services.AddProblemDetailsErrors();
builder.Services.Configure<RouteHandlerOptions>(options => options.ThrowOnBadRequest = false);
builder.Services.AddHealth();
builder.Services.AddInfrastructure();
builder.Services.AddSingleton(TimeProvider.System);
builder.Services.AddScoped<CreateResourceHandler>();
builder.Services.AddScoped<GetResourceHandler>();
builder.Services.AddScoped<ListResourcesHandler>();

var app = builder.Build();

app.UseProblemDetailsErrors();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseHttpsRedirection();

app.MapHealth();
app.MapResources();

app.Run();
