using System.Collections.Concurrent;
using Collarbell.Api.Modules.Supplies;

namespace Collarbell.Api.Tests;

/// <summary>
/// Stands in for Open Pet Food Facts or UPCitemdb: knows the products a test puts in, and can be "down". Tests use
/// their own barcodes, so products of other tests don't get in the way.
/// </summary>
public sealed class FakeProductDatabase(ProductLookupSource source) : IProductDatabase
{
    public ProductLookupSource Source => source;

    public ConcurrentDictionary<string, ProductDetails> Products { get; } = new();

    /// <summary>Barcodes for which the database can't be reached.</summary>
    public ConcurrentDictionary<string, bool> Down { get; } = new();

    /// <summary>Every barcode asked for.</summary>
    public ConcurrentQueue<string> Asked { get; } = new();

    public Task<ProductDetails?> FindAsync(string gtin, string locale, CancellationToken ct)
    {
        Asked.Enqueue(gtin);
        if (Down.ContainsKey(gtin))
        {
            throw new HttpRequestException("The product database is down.");
        }

        return Task.FromResult(Products.GetValueOrDefault(gtin));
    }
}
