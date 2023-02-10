class Network
  include Mongoid::Document
  include Mongoid::Timestamps

  field :slug, type: String
  field :name, type: String

  has_many :videos, dependent: :destroy
  has_many :vterms, dependent: :destroy
  has_many :vedges, dependent: :destroy

  def self.admin_fields
    {
      slug: :text,
      name: :text,
      videos: :collection,
      vterms: :collection,
      vedges: :collection
    }
  end

  def filter_words
    case slug
    when 'daniel'
      %(
        game b
        daniel schmachtenberger
      ).split("\n").map(&:strip).reject(&:blank?)
    when 'jim'
      []
    when 'jordan'
      []
    end
  end

  def prompt
    case slug
    when 'daniel'
      'as if written by Daniel Schmachtenberger'
    when 'jim'
      'as if written by Jim Rutt, host of the Jim Rutt Show podcast'
    when 'jordan'
      'as if written by Jordan Hall, aka Jordan Greenhall'
    end
  end

  def interesting
    case slug
    when 'daniel'
      %(
        apex predator
        arms race
        artificial intelligence
        biosecurity
        blockchain
        bretton woods
        catastrophe weapon
        catastrophic risk
        civilizational collapse
        climate change
        collective action
        collective intelligence
        complexity science
        confirmation bias
        conflict theory
        coordination failure
        critical infrastructure
        decision making
        dunbar number
        dystopia
        embedded growth obligation
        emergent property
        epistemic commons
        existential risk
        existential threat
        exponential growth
        exponential tech
        fourth estate
        game b
        game theory
        generator function
        global governance
        human nature
        hypernormal stimuli
        liquid democracy
        materials economy
        metacrisis
        mistake theory
        multipolar trap
        mutually assured destruction
        narrative warfare
        nation state
        network dynamics
        network theory
        nonlinear dynamics
        nuclear weapon
        open society
        open source
        paperclip maximizer
        permaculture
        perverse incentive
        planetary boundary
        plausible deniability
        race to the bottom
        regenerative agriculture
        rivalrous dynamics
        self-terminating
        sensemaking
        social media
        social structure
        social system
        social tech
        superorganism
        superstructure
        supply chain
        systems thinking
        third attractor
        web3
    ).split("\n").reject { |x| x.blank? }.map { |x| x.strip }
    when 'jim'
      %(
        agi
        abiogenesis
        agent-based modeling
        antifragile
        attractor
        causality
        crypto
        cultural evolution
        dunbar number
        edge of chaos
        emergence
        evolution
        evolutionary computing
        evolutionary psychology
        fermi paradox
        free will
        game b
        integrated information theory
        intellectual honesty
        lord of the rings
        maslow's hierarchy
        membrane
        origin of life
        phase change
        prigogine
        proto b
        protocol
        psychotechnology
        quantum foundations
        strong links
        ubi
        universal basic income
        virtue ethics
        warm data
        archetype
        artificial intelligence
        boltzmann brain
        bottom-up
        cambrian explosion
        climate change
        cognitive science
        coherence
        coherent pluralism
        collective action
        collective intelligence
        complex system
        complexity science
        consensus process
        conviviality
        custodial species
        deep learning
        deterministic chaos
        epidemiology
        externality
        flow state
        free speech
        game theory
        global workspace theory
        governance
        gradient descent
        hierarchical complexity
        integral theory
        intentional community
        left hemisphere
        liquid democracy
        machine learning
        meaning crisis
        memetic tribe
        memetic warfare
        metamodernism
        metamodernity
        metaverse
        monetary system
        money-on-money return
        multipolar trap
        mutual credit
        nervous system
        network effect
        neural network
        nihilism
        non-rivalrous
        nuclear power
        nuclear weapon
        omega point
        open source
        permaculture
        phase transition
        philosophy of science
        psychedelic
        quantum mechanics
        regen villages
        regenerative
        relevance realization
        self-organization
        self-organizing
        self-driving car
        sensemaking
        serious play
        social capital
        social justice
        social media
        social network
        solar energy
        urban planning
    ).split("\n").reject { |x| x.blank? }.map { |x| x.strip }
    when 'jordan'
      %(
        adjacent possible
        artificial intelligence
        blue church
        choice making
        collective intelligence
        complex system
        culture space
        deep code
        deep state
        diminishing returns
        distributed cognition
        feedback loop
        felt sense
        game theory
        hill climbing
        liminal space
        low-hanging fruit
        mass media
        meaning crisis
        mental health
        pair bonding
        participatory knowing
        phase transition
        possibility space
        psychotechnology
        reciprocal narrowing
        reciprocal opening
        relevance realization
        simulated thinking
        situational assessment
        social media
        sovereignty
        subjective well-being
        unconventional warfare
      ).split("\n").reject { |x| x.blank? }.map { |x| x.strip }
    end
  end

  def plurals
    interesting.map { |term| term.pluralize }
  end

  def hints
    case slug
    when 'daniel'
      {
        'self-terminating' => 'as if written by Daniel Schmachtenberger, in the context of failed civilizations',
        'embedded growth obligation' => 'as if written by Daniel Schmachtenberger, in the context of failed civilizations',
        'generator function' => 'as if written by Daniel Schmachtenberger, in the context of failed civilizations, without reference to computing or programming. The definition should start "A generator function, in the context of failed civilizations"'
      }
    when 'jim'
      {}
    when 'jordan'
      {}
    end
  end

  def youtube_ids
    case slug
    when 'daniel'
      %w[E_cyCuCKQhs eq_gaazINkA 7LqaotiGWjQ hGRNUw559SE _b4qKv1Ctv8 YPJug0s2u4w hUE0Q7lv94k db-Xn2gzGxU tJQac_T_rPo MYCvaVqZebA 0v5RiMdSqwk nQRzxEobWco 9QGrffjOFko GWk-ZpJdRFg 8Es_WTEgZHE _7aIgHoydP8 p4NlLuNj0v8 Z_wPQCU5O6w eh7qvXfGQho Kt4f_gcEnh4 G70qtM66iY8 8XCXvzQdcug 3bxzo79SjpE XQpoGL0yIFE aX5n0DYXnUQ LLgv2QJRYSg fWshjsIrUSI mQstRd7opv4 aNj8UiPgqqQ ya_p4RIorXw ndehWd9N9Z4 ZNcyc_sEtpU _eoB4g3gCmw wO1WVguNQAM _BofVO-4yNc MBcoTHlD8r8 Nkv5mpBA8o4 hKvVdGNzCQk UoHmEYZLqmk R2sIG6l4uU0 zi5-90TnI3Y lls_2tfWcUI ZCOfUYrZJMQ V2wuvrgYyh8 01rVKtbqtnA 0snD5FZCVII rrozCypcUx4 MRV-ESY6Obs qd5vPs9cRYI 8xDgk0uGw_s _Oflv3u0HEA VPAOzlqcGIQ SioR1jgdhnk kTFqnPEyweE Pyy3veuvXVE tQkQrc3Ant4 aZhiwxxn3K8 weZqeVh2Exs Wk2HinTpRwQ E0_j2-pLunY q8mleq4VNm8 2YgNYdL7HTk dGW5J3EbOUY m3VGg2kQWR4 Fl8pGMjM9kM LtbMps1PDFc jUn7_85R0M4 X_7U1ApSzaM VLGjzGbPxVI zpGrU99fAA8 WVEP0zAK-xQ U0YJ0C81n4s IfoPitvLY7c 2fAy18JawYI H0ocPsqBKS4 PKz9TAsqsRo Kep8Fi_rUUI 611ctV-HStQ tNO_3JFLVUc I9I7p1eho3k dtxNgnBw8Ao U1QJtDCCMLA pSQqaclDmZ4 SkItTnRJ_1M 2SopiHEqfRQ uhVArr7R-aU ammJN0yCCbs 4pf38y5rFrE zQ0l56vjTss kbg8nHuNggU A41z7UD3NsU Kr2nhiNCOXo Fj6UjIV2VQQ 2p-GlhLQdY0 MZMSs2SLmSw WRohQKNNuM4 EfNgW-On6hw i6-cc71ALQc QAd9O6a6R5w 9LquQ4GgY5Y ZIV1Uw2VyF8 YcIlDc96Azs tWfyOU07vgE PnrL_9V0QMs tj9RceVQBxc mPHUN18BbNo ztfz5EdYxL0 CElwzOUbsGg ZXHagfNHKws HjChfAJy0g8 1rj9NtQafb8 LmlbhD6LbSA SxS1rIXXaQ4 fowcm7b8Dlw qwILqzrvncQ BWfwZvfaoYA yTSWDnhK-M4 vPSXsOeX6lM 6fWfvO72vAw Cqq840poanw GPumhxH3JHA hV9PJhhqw5w zWpKVTyx8R0 vLwlsQYBQ1w fcgOxHHp_i8 EsvG3zbKGa4 kLJ2QztR3ug Z7-Od0e0gq0 QZ9iRByzUJs 22TrTXZLmmU OLWihHrj6zs qKFY5OflSrc xnfOuiddmFY NABTu6VOroc ig-bWt2y1VE IVyq4WpmvRM Xhrr-fJCTWY j6nJmVcx6v8 BIKDNStlnL4 SWEoLn54d4U qxtkUJPg7os K2_1tnGL5eQ JBU06Wswc7c 2HfbPJXHmQM E8cSGX02bqA DcNG-gGxroY toZPGhq3VqQ a6ejROOyHW0 5Rxhyvyq7ew J9f5tuzzFxY mm9AE-oHlPk kmHyhJdSW5o z2rYFnDx6nQ IqLELspOa7g xreo0fw-4_A nOnyWZMvkg4 jzYOybiP7Dg 2zD0kQB6d0M uEAsKkjDURs 3lil4invvSI jQAhGT0nKkI 9TQHtaRXntQ vPbOyjtv5PU LetPkDGIyy0 ggf4ouFJ2x0 eTeLyBxjX9k T9v0IAFPrm0 U6Fo8Ee0x8Q -WQ7QbJGWRE 1r2TSpSNjDI ib4v9cG_ZA8 0dYoSctj3C8 9psdN65IzOw FschjBcFElk vfKR0Nyp--Q AdlYvrKa16c z7DZCChfmf8 17KFrJj1sMQ iF8R1hJT-24]
    when 'jim'
      %w[LB2_YsOOdBA d_8j6iV4GLk v_wwavpdbKE m60k9CudP_U rIomvkynQtY OFnDgmoTA80 sfzcVR4vq0Q LiVI5riH2rE OkASzXiy68k 3UKnMW3Iqp4 GcGqJpIBzdg sjMstcGsLXw hfwpZS7jqAM isIrLmYTdvU nZC2jYIpkXo yShKhjz0-ds ISiBPnOFoUc -1M4dmn4KVc 7ZVpzuTp86w VXPHqdf34Vk UriHET7EHT0 g6PNZisaCU4 JzHybkkqg6k 0KXq0JpYoEM UGE9c4d26CU 9u8SpXB0hfA ugaxC6l88s0 9VQpEGlydI8 -pjnBS0tQHk td4JzeGMMHY MAfx0KKn70Q VGFfO_djk3c 2gNtK9JOsc8 iAWa6yyFn2E rbgmfnGwS64 -LKXw0rSrE8 w7iMNPW16lY rwMVRhgwV0U g6e83obW8j4 XzCsmWwIIac ISwmrPmH3Vs PKOU3p9VoOw 17U3HZJTHHI 7rOckMybwN0 wn0MjG-ZO1U LTKS68N_fhI 4J4kSaTdRl4 C7FRwneNfdI yrCW5jvBhm0 4cmD9UwlQj8 NtzCBvoUH7s cVkuzaZx7i0 msPrTTebGZE JU1yCl91GRI J4syZHmCWGY lzmcXj47NFA lAxZ-V3XOgc 7TTq4pVYUEQ xT4bal1_FU8 5hPHjoJVYOc t6LNcVEAWI4 5tRrWaRevrQ WXTRW9kS-ds OicptQbgvcU Pn_dNECTzQY Rsl1n-4ptfQ xCgHrC20Di0 w3Mqmv_sfDc kRyhwtCxST8 S3TYdhI-pXk 4dScqlfahQM 4uinH3mwMb0 53mTlbgBASs SOMPRYpa6ms y7TaiNWaJWk mwMUHjX1eUw kyXZtp-Htu8 4YlX7I2O3o8 UUHCa2xaTzg USebpdjVQYk OHreP6ueTB8 CFxgRP6D5yE iXvxdq5D6yI EXTjVK7Qur0 wWQ1NstAVgs GAj2UbIJfaY 99pHgLmbHN8 6xFYuKuvIis bHCg8bhtbqs xFGC5t-egPs bI8ABLMoUiY A3i2EvXZb2c CMuHSIA4-iA KPcqOm_ObW0 xoN_Chej6tM 7yj7wjOLpX4 gbQxx5QDTGI V1CzSyn_z3k Zmc-niGxXKo xmuj3xPmgAc 4iTdV2Tnr8U JBU06Wswc7c O_Woj6qfAds hO0sfZhRlnw ysYDu7EghJ0 jZsOuDHXzuo cV7SASnUl-M OFCkAILMfrA r-FuZc3qmmE p1sy4CViJsY hs0Abf5OuoE U-suND5XFoM ZTSqFJjMYOA Oka3XTDxbqY Axuiw7kmMiM yLUcmXmXrS0 MQ5XDrHAJxg ONNLF7nQOFI 9QHbIgPdeZk exStLnmYfP0 Ux-SChkpEHs O0n4ASrERJk fPEyl91y3Ns ect7JDkDFWg g9tInaFlh8c Yh6cn_DbSJQ LV_H0F7096w CuwRZkp5EIg D4psLcd8FsM wx2dbMaZXYY fBsFTvfFzYc VZwueJdAzSA s_KHM0e1iK0 w0zUsfKjBSA gyGNVtXAKZM xdvy14eDW6I at6QGejaIIo 73apSEyH5aI tQcZamf1bpA&t=2s OiSnJHUynwI 5qx0wUSXlZk vUwlp6R57p0 nGYN_kNEIl0 M81DMSNXdpw 1aEtC1Fizag HeTUuwtiASU YCAMRMIaLBo _1GRnUOFXWE l4reBLNYceA rlcQgHoXVCA hhxxQc2vldE Kq9JDNaoToE MT5F14-jOEw UJWSNm50TyA fz1zqe0l8oA yR_Ju6rYFzA uEizThMxphE DrriAJuBXo0 3LhQAtVmoKw y1ESPbKrEsY AgZNWREGbjw 3lil4invvSI&t=2835s eP7BnfCa0EQ UiY2vRLu80Q TKxSScPSv0U 57ywT36z2u4 e5a2LjO26ec 76_I8Cwmowo zNPIdY-8Im0 m3ISJRzjPzw x0bHMn68kL8 y8NZzWRcC30 xqcGapPVzh4 UNVUUcakbPo FNxX7vpY_1Q aaZRsRdJHF0 5X08uBJP-XM JuDlSOxKjBA _pnQ1bj_C1Y JAHNNrVn30U whRVg1itU50 bwiKCvyPJow bzweztI5L0w KfbHfkdUnJo 0Qma07i4Swo LC3WplYNP5E cCFw9iz6Hog 2v-NaXywBfg 0r0K5801WiI DeNOLulwSeA M-BcL01tVao -DEtOc9TwJQ YGimyElav-k zC_xxCnAoIA KUAZ3wVLgQ0 rZNd9nuOsAY X7nfej84-kI zb7NkxbmxWE HxDi03y9SHc n9V8FFYj5gw eHiFuuRW_WE L6AcSUn3ei0 NHe4brukBq8 ZdKeJEq2s5Q S78ZMN_6DXc INex4hPCFUs Eo4H_h-g4B4 KKYKPA6c-u4 Jdlvu7sQDiA GJKkQFtsG6I HMmlu0LH4Qc zPxdOFRmEzM 6uIhL8GRgbU XmVfJTfUv_s hZ9k6doiSwY jbVlRHCMW_o 7gAqCSGbom8 dE_orUarO_s vcPgajWjQFk V0G_JCvXw1E qCJLkwzNy_4 fMxcZnRxhFs F026jgAH8jI zicE9XospFs ZZcKeYVuN2E 9DmTwmZqNqE wommAGYvkI0 0QVM8US-uqc LfYAmf_pfM0 JtcM-XRL3eA 2j4-kpFaVrQ CNfNbbUXbiI aF2HCRR-5xU W9xQVu5CL9w Mn1OZPbN0Do PYHrVH39XtY EGryvLGLiME NPEgWBogOvA jOZzi1Wj0ks Q7mxNgxlsgo a2mZqs3g5ks S61lllaBrAw 4unnL_lflKY 8JyC60Nl33M 53oDzFn32pk Ggc7ppOzKMo tLrPO6ktttE Py4jsJelyw8 sYNaYdmCC5Y fmIwo_A_K48 2TFI56ZMXbo Cn8kbDxq4xY gL5pB7mPpe4 PWMnEF9ZYCk 6eKvI0QhKFI Z2FSPaa9mDg JAr7pdHa_UY rU3mfFXhEPk trZPxcbZsHc O22A1-Lb0KM UtBmFOflpQs -LKF_wYAQDQ 9psdN65IzOw JDZbH9w8QiQ SMkYJfCs9ss gfTq9qfRCgc pt4fdiyOz10]
    when 'jordan'
      %w[3MbiJwhYdzI haeHZszpCec RrUQOt6iN8Q JfN9-sawjHM l8kj5jsC56A thHJP9M1Ev0 PeUNt28ljsk BHuswWHEdOc YYYlcV9AiGA 5ajPo3S777E 33pbnPVrrsg Ft_7n3eUytQ hrdRQX2lHRk wVfp0GwFk7c AiR1FoN3G_I Nb74f0gg1Qs 59BjCaNRK74 43uYJnvFWyc b5ECbxr-CGg N6YhhgrLb1c HnUDnRXi2sI tsCAnUk7LMg dE_orUarO_s a2mZqs3g5ks DPcQ6igOTZ4 L6y_KrZZkhU cmQ-TRj1jF0 Qqa5deNZl04 jvzJvwUJWtk lcDNqys1YgQ pFWt_u7ffFE Lb8uelYBekE 933qDMh1J3g gQlDjWq_XmQ trZPxcbZsHc MDZwyvz5DEU D48Yv_5dHOU qknAL5R_1Gc H6xfZZ5T0Lk UovLJTLbFhU nl48eFZGRq8 7g6rwOa-pGs qEqVkmBhBmo TU_ny1ClpKI 1U7JLdQ37nI I7TMrCCQmBY aRjbQCXHNVI TuVxD8LixEM tyI1dpyrVb4 nEWyVrxXFCY BP14a6fjua0 EL6abRGAgyU 8Es_WTEgZHE Tg0CaCplHjs _j3cCrpXERg awmqIySF2Gs nLFFNpTQla0 Dsrw7Sq0GGs K6wKnR8F5w4 s6KSJqMI0NU tQGksc1I7rA _SmGMJzWHK4 rmZEHhgp7U8 ODTlCTlBQuQ 64HGcESw5-8 EL_S0p9UVcM Rqjx1Nd-8-A LhlMWdfUZ1Q BtCopAFBH6M OUv-ZOM0dOo 4NEvuQWR3oo 90MITwU8Yfw mGNrf_nwKy4 UoHmEYZLqmk q1_r0Q1Y6UM RfyHqkb8YJY a7MHHklZI0Q DPPnuE24jas 9i60-87ufEI r3OlG4OmczI gZANU8pl0gQ DOv8CmUemoA nBm_SFN6iME mbmKlJrWR2w _fCCVt6Vfjc rmJA8EPySNs I2DAjjS0rcM]
    end
  end

  def edgeless
    vterms.where(:id.nin => vedges.pluck(:source_id) + vedges.pluck(:sink_id))
  end

  def populate_videos
    youtube_ids.each { |youtube_id| videos.create(youtube_id: youtube_id) }
  end

  def populate_vterms
    (interesting - vterms.pluck(:term)).each { |term| vterms.create(term: term) }
    edgeless.each { |source| source.find_or_create_vedges }
    vterms.set(see_also: nil)
    vterms.each { |vterm| vterm.set_see_also! }
  end

  def find_or_create_vedge(source, sink)
    if !(vedge = vedges.find_by(source: source, sink: sink)) && !(vedge = vedges.find_by(source: sink, sink: source))
      vedge = vedges.create(source: source, sink: sink)
    end
    vedge
  end
end
