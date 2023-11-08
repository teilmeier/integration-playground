using System.Net;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;
using Azure.Messaging.EventGrid;

namespace IntegrationPlayground.SalesOrder.Publisher
{
  public class PublishOrderEvent
  {
    private readonly ILogger _logger;

    public PublishOrderEvent(ILoggerFactory loggerFactory)
    {
      _logger = loggerFactory.CreateLogger<PublishOrderEvent>();
    }

    [Function("PublishOrderEvent")]
    [EventGridOutput(TopicEndpointUri = "EVENTGRID_URI", TopicKeySetting = "EVENTGRID_TOPICKEY")]
    public SalesOrderEvent Run([HttpTrigger(AuthorizationLevel.Function, "post")] HttpRequestData req, [FromBody] SalesOrder salesOrder)
    {
      _logger.LogInformation("New sales order request.");

      if (!string.IsNullOrEmpty(salesOrder.PartNumber) && salesOrder.Amount > 0)
      {
        var order = new SalesOrderEvent(
          Guid.NewGuid().ToString(),
          "SalesOrderEvent",
          "SalesOrderReceived",
          "AzureFunctions",
          "NewSalesOrder",
          DateTime.UtcNow,
          salesOrder
        );

        return order;
      }

      else
      {
        _logger.LogError("Invalid sales order request.");
        return null;
      }
    }
  }

  public record SalesOrderEvent(string id, string topic, string subject, string source, string type, DateTime eventtime, SalesOrder data, string specversion = "1.0");

  public record SalesOrder(string PartNumber, decimal Amount );
}

