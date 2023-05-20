mod collator_opts;

use icu_collator::*;
use icu_locid::Locale;
use collator_opts::CollatorOptions;
use rustler::NifResult;

#[rustler::nif]
fn sort<'a>(
    locale_tag: &str,
    list: Vec<&'a str>,
    opts: CollatorOptions,
) -> NifResult<Vec<&'a str>> {
    let locale: Locale = locale_tag.parse().map_err(|_| rustler::Error::BadArg)?;
    let collator =
        Collator::try_new_unstable(&icu_testdata::unstable(), &locale.into(), opts.into()).unwrap();

    let mut list = list;
    list.sort_by(|first, second| collator.compare(first, second));
    Ok(list)
}

rustler::init!("Elixir.Cldr.Collation.Nif", [sort]);
