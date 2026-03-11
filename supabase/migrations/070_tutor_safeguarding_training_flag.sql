                                                                                                                          -- ======================================================
                                                                                                                          -- MIGRATION 070: Tutor Safeguarding Training Flag
                                                                                                                          -- ------------------------------------------------------
                                                                                                                          -- - Adds safeguarding_training_completed_at to tutor_profiles
                                                                                                                          --   so we know tutors have seen and acknowledged onsite safeguarding guidance
                                                                                                                          --   before taking onsite sessions.
                                                                                                                          -- ======================================================

                                                                                                                          ALTER TABLE public.tutor_profiles
                                                                                                                            ADD COLUMN IF NOT EXISTS safeguarding_training_completed_at TIMESTAMPTZ;

                                                                                                                          COMMENT ON COLUMN public.tutor_profiles.safeguarding_training_completed_at IS
                                                                                                                            'When the tutor completed the in-app safeguarding micro-training / acknowledgement for onsite sessions.';

