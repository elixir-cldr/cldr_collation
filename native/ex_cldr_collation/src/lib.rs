use icu_collator::*;
use icu_locid::Locale;
use rustler::{NifMap, NifResult, NifUnitEnum};

#[derive(NifUnitEnum)]
enum Casing {
    Sensitive,
    Insensitive,
}

#[derive(NifMap)]
struct ComparisonOptions {
    casing: Casing,
}

impl From<ComparisonOptions> for CollatorOptions {
    fn from(opts: ComparisonOptions) -> Self {
        let mut collator_options = CollatorOptions::new();

        match opts.casing {
            Casing::Insensitive => collator_options.strength = Some(Strength::Primary),
            Casing::Sensitive => (),
        }

        collator_options
    }
}

#[rustler::nif]
fn sort<'a>(
    locale_tag: &str,
    list: Vec<&'a str>,
    opts: ComparisonOptions,
) -> NifResult<Vec<&'a str>> {
    let locale: Locale = locale_tag.parse().map_err(|_| rustler::Error::BadArg)?;
    let collator =
        Collator::try_new_unstable(&icu_testdata::unstable(), &locale.into(), opts.into()).unwrap();

    let mut list = list;
    list.sort_by(|first, second| collator.compare(first, second));
    Ok(list)
}

rustler::init!("Elixir.Cldr.Collation.Nif", [sort]);
