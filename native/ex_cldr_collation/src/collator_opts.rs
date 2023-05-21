/// Due to Rust's orphan rule, we can't implement NifMap directly on icu_collator::CollatorOptions.
/// Furthermore, icu_collator::CollatorOptions is marked #[non_exhaustive], so we can't rely
/// on its fields being stable.
/// Thus we need to create our own version of CollatorOptions that we can use in our NIF API, and can be easily converted to icu_collator::ComparisonOptions.
/// This also allows us the flexibily to adjust the NIF API if we so choose, while still being compatible with icu_collator.
use rustler::{NifMap, NifUnitEnum};

#[derive(NifUnitEnum)]
pub enum Strength {
    Primary,
    Secondary,
    Tertiary,
    Quaternary,
    Identical,
}

impl From<Strength> for icu_collator::Strength {
    fn from(opts: Strength) -> Self {
        match opts {
            Strength::Primary => icu_collator::Strength::Primary,
            Strength::Secondary => icu_collator::Strength::Secondary,
            Strength::Tertiary => icu_collator::Strength::Tertiary,
            Strength::Quaternary => icu_collator::Strength::Quaternary,
            Strength::Identical => icu_collator::Strength::Identical,
        }
    }
}

#[derive(NifUnitEnum)]
pub enum AlternateHandling {
    NonIgnorable,
    Shifted,
}

impl From<AlternateHandling> for icu_collator::AlternateHandling {
    fn from(opts: AlternateHandling) -> Self {
        match opts {
            AlternateHandling::NonIgnorable => icu_collator::AlternateHandling::NonIgnorable,
            AlternateHandling::Shifted => icu_collator::AlternateHandling::Shifted,
        }
    }
}

#[derive(NifUnitEnum)]
pub enum CaseFirst {
    Off,
    LowerFirst,
    UpperFirst,
}

impl From<CaseFirst> for icu_collator::CaseFirst {
    fn from(opts: CaseFirst) -> Self {
        match opts {
            CaseFirst::Off => icu_collator::CaseFirst::Off,
            CaseFirst::LowerFirst => icu_collator::CaseFirst::LowerFirst,
            CaseFirst::UpperFirst => icu_collator::CaseFirst::UpperFirst,
        }
    }
}

#[derive(NifUnitEnum)]
pub enum MaxVariable {
    Space,
    Punctuation,
    Symbol,
    Currency,
}

impl From<MaxVariable> for icu_collator::MaxVariable {
    fn from(opts: MaxVariable) -> Self {
        match opts {
            MaxVariable::Space => icu_collator::MaxVariable::Space,
            MaxVariable::Punctuation => icu_collator::MaxVariable::Punctuation,
            MaxVariable::Symbol => icu_collator::MaxVariable::Symbol,
            MaxVariable::Currency => icu_collator::MaxVariable::Currency,
        }
    }
}

#[derive(NifUnitEnum)]
pub enum CaseLevel {
    Off,
    On,
}

impl From<CaseLevel> for icu_collator::CaseLevel {
    fn from(opts: CaseLevel) -> Self {
        match opts {
            CaseLevel::Off => icu_collator::CaseLevel::Off,
            CaseLevel::On => icu_collator::CaseLevel::On,
        }
    }
}

#[derive(NifUnitEnum)]
pub enum Numeric {
    Off,
    On,
}

impl From<Numeric> for icu_collator::Numeric {
    fn from(opts: Numeric) -> Self {
        match opts {
            Numeric::Off => icu_collator::Numeric::Off,
            Numeric::On => icu_collator::Numeric::On,
        }
    }
}

#[derive(NifUnitEnum)]
pub enum BackwardSecondLevel {
    Off,
    On,
}

impl From<BackwardSecondLevel> for icu_collator::BackwardSecondLevel {
    fn from(opts: BackwardSecondLevel) -> Self {
        match opts {
            BackwardSecondLevel::Off => icu_collator::BackwardSecondLevel::Off,
            BackwardSecondLevel::On => icu_collator::BackwardSecondLevel::On,
        }
    }
}

#[derive(NifMap)]
pub struct CollatorOptions {
    strength: Option<Strength>,
    alternate_handling: Option<AlternateHandling>,
    case_first: Option<CaseFirst>,
    max_variable: Option<MaxVariable>,
    case_level: Option<CaseLevel>,
    numeric: Option<Numeric>,
    backward_second_level: Option<BackwardSecondLevel>,
}

impl From<CollatorOptions> for icu_collator::CollatorOptions {
    fn from(opts: CollatorOptions) -> Self {
        let mut collator_options = icu_collator::CollatorOptions::new();

        collator_options.strength = opts.strength.map(|s| s.into());
        collator_options.alternate_handling = opts.alternate_handling.map(|a| a.into());
        collator_options.case_first = opts.case_first.map(|c| c.into());
        collator_options.max_variable = opts.max_variable.map(|m| m.into());
        collator_options.case_level = opts.case_level.map(|c| c.into());
        collator_options.numeric = opts.numeric.map(|n| n.into());
        collator_options.backward_second_level = opts.backward_second_level.map(|b| b.into());

        collator_options
    }
}
