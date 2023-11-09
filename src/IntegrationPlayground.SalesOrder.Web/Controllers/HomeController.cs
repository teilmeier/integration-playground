using System.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using IntegrationPlayground.SalesOrder.Web.Models;
using Newtonsoft.Json;
using System.Text;
using System.Net;

namespace IntegrationPlayground.SalesOrder.Web.Controllers;

public class HomeController : Controller
{
  private readonly ILogger<HomeController> _logger;
  private static readonly HttpClient _httpclient = new HttpClient();
  private readonly IConfiguration _configuration;

  public HomeController(IConfiguration configuration, ILogger<HomeController> logger)
  {
    _configuration = configuration ?? throw new ArgumentNullException(nameof(configuration));
    _logger = logger;
  }

  public IActionResult Index()
  {
    return View(new HomeViewModel { Message = string.Empty });
  }

  public IActionResult Privacy()
  {
    return View();
  }

  [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
  public IActionResult Error()
  {
    return View(new ErrorViewModel { RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier });
  }
  public IActionResult SendSalesOrder(string partNumber, decimal amount)
  {
    var salesorderJson = new SalesOrderMessage { PartNumber = partNumber, Amount = amount };

    var salesOrderApiUri = _configuration["SalesOrderApiUri"];
    var salesOrderApiKeyParam = _configuration["SalesOrderApiKeyParam"];
    var salesOrderApiKeyValue = _configuration["SalesOrderApiKeyValue"];

    if (string.IsNullOrEmpty(salesOrderApiUri) || string.IsNullOrEmpty(salesOrderApiKeyParam) || string.IsNullOrEmpty(salesOrderApiKeyValue))
    {
      throw new ArgumentNullException("SalesOrderApiUri, SalesOrderApiKeyParam or SalesOrderApiKeyValue is null or empty");
    }

    var request = new HttpRequestMessage()
    {
      RequestUri = new Uri(salesOrderApiUri),
      Method = HttpMethod.Post,
      Content = new StringContent(JsonConvert.SerializeObject(salesorderJson), Encoding.UTF8, "application/json")
    };

    request.Headers.Add(salesOrderApiKeyParam, salesOrderApiKeyValue);

    var result = _httpclient.SendAsync(request).Result;
    string message;

    switch (result.StatusCode)
    {
      case HttpStatusCode.OK:
        message = "Order submitted successfully.";
        break;
      case HttpStatusCode.NoContent:
        message = "Order submission failed.";
        break;
      case HttpStatusCode.TooManyRequests:
        message = "Too many requests. Please try again later.";
        break;
      default:
        message = "An unknown error occured.";
        break;
    }

    return View("Index", new HomeViewModel { Message = message });
  }
}

public class SalesOrderMessage
{
  [JsonProperty("partnumber")]
  public string? PartNumber { get; set; }
  [JsonProperty("amount")]
  public decimal Amount { get; set; }
}