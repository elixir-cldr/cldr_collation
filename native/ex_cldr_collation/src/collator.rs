use icu_collator::Collator;
use icu_locid::Locale;
use rustler::NifResult;

fn parse_locale(locale_tag: &str) -> NifResult<Locale> {
    locale_tag.parse().map_err(|_| rustler::Error::BadArg)
}

pub fn new(
    locale_tag: &str,
    opts: impl Into<icu_collator::CollatorOptions>,
) -> NifResult<Collator> {
    let locale: Locale = parse_locale(locale_tag)?;
    let collator =
        Collator::try_new_unstable(&icu_testdata::unstable(), &locale.into(), opts.into()).unwrap();
    Ok(collator)
}
