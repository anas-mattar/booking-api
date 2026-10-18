namespace BookingApi.Api.Errors;

// Contract: specs/001-solution-scaffold/contracts/http-baseline.md (error schema).
// One RFC 9457 problem details shape for every error response, in every environment.
public static class ProblemDetailsSetup
{
    public static IServiceCollection AddProblemDetailsErrors(this IServiceCollection services)
    {
        services.AddProblemDetails();
        return services;
    }

    public static IApplicationBuilder UseProblemDetailsErrors(this IApplicationBuilder app)
    {
        // Registered in every environment, so the Development exception page never answers.
        app.UseExceptionHandler();
        app.UseStatusCodePages();
        return app;
    }
}
