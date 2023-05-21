use icu_collator::Collator;
use rustler::ResourceArc;
use std::sync::Mutex;

pub struct CollatorResource {
    collator: Mutex<Collator>,
}

impl CollatorResource {
    pub fn new(collator: Collator) -> Self {
        Self {
            collator: Mutex::new(collator),
        }
    }

    pub fn new_arc(collator: Collator) -> ResourceArc<Self> {
        ResourceArc::new(Self::new(collator))
    }

    pub fn collator(&self) -> &Mutex<Collator> {
        &self.collator
    }
}

pub type CollatorResourceArc = ResourceArc<CollatorResource>;
