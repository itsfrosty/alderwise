import Domain
import Testing

@Test
func merchantNormalizerProducesStableComparableNames() {
    let normalizer = MerchantNormalizer()

    #expect(normalizer.normalize(" SQ *Coffee   Shop SUNNYVALE CA null XXXXXXXXXXXX1234 ") == "sq coffee shop sunnyvale ca")
    #expect(normalizer.normalize("Coffee-Shop, Inc.") == "coffee shop inc")
}
