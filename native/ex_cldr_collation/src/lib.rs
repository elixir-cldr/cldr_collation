mod collator;
mod collator_opts;
mod resource;

use collator_opts::CollatorOptions;
use resource::{CollatorResource, CollatorResourceArc};
use rustler::{Env, NifResult};

#[rustler::nif]
fn create_collator(locale_tag: &str, opts: CollatorOptions) -> NifResult<CollatorResourceArc> {
    let collator = collator::new(locale_tag, opts)?;
    Ok(CollatorResource::new_arc(collator))
}

#[rustler::nif]
fn sort<'a>(
    locale_tag: &str,
    list: Vec<&'a str>,
    opts: CollatorOptions,
) -> NifResult<Vec<&'a str>> {
    let collator = collator::new(locale_tag, opts)?;

    let mut list = list;
    list.sort_by(|first, second| collator.compare(first, second));
    Ok(list)
}

#[rustler::nif]
fn sort_using_collator(collator_arc: CollatorResourceArc, list: Vec<&str>) -> Vec<&str> {
    let collator = collator_arc.collator().lock().unwrap();
    let mut list = list;
    list.sort_by(|first, second| collator.compare(first, second));
    list
}

fn load(env: Env, _info: rustler::Term) -> bool {
    rustler::resource!(CollatorResource, env);
    true
}

rustler::init!(
    "Elixir.Cldr.Collation.Nif",
    [sort, create_collator, sort_using_collator],
    load = load
);
