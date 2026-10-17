import Foundation

enum FrasesHoot {

    static func elegir(_ opciones: [String], semilla: Int = hoy) -> String {
        opciones[((semilla % opciones.count) + opciones.count) % opciones.count]
    }

    static var hoy: Int { Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0 }

    static func mayusculaInicial(_ s: String) -> String { s.prefix(1).uppercased() + s.dropFirst() }
    static func minusculaInicial(_ s: String) -> String { s.prefix(1).lowercased() + s.dropFirst() }

    static func repasoPendiente(asignatura a: String, dia d: String, tema t: String) -> String {
        elegir(L3([("\(a) \(d) y \(t) sigue en luna nueva. Yo solo lo digo.",
                    "\(a) \(d) and \(t) is still a new moon. Just saying.",
                    "\(a) \(d) e \(t) è ancora in luna nuova. Io lo dico e basta."),
                   ("\(t) lleva días esperándote. Las lunas no se llenan solas.",
                    "\(t) has been waiting for days. Moons don't fill themselves.",
                    "\(t) ti aspetta da giorni. Le lune non si riempiono da sole."),
                   ("\(a) \(d). \(t), sin tocar. Me pongo nervioso por ti.",
                    "\(a) \(d). \(t): untouched. I'm nervous for you.",
                    "\(a) \(d). \(t): zero ripassi. Mi agito io per te.")]))
    }

    static func repasoEnMarcha(tema t: String) -> String {
        elegir(L3([("\(t) va por la mitad. Un empujón más y luna llena.",
                    "\(t) is halfway there. One more push and it's a full moon.",
                    "\(t) è a metà. Una spinta e luna piena."),
                   ("Media luna en \(t). La otra media no se va a estudiar sola.",
                    "Half a moon on \(t). The other half won't study itself.",
                    "Mezza luna su \(t). L'altra metà non si studia da sola."),
                   ("Vas bien con \(t). No te emociones, que mañana te pregunto.",
                    "Going well with \(t). Don't get cocky, I'm quizzing you tomorrow.",
                    "Su \(t) vai bene. Non montarti la testa, domani ti interrogo.")]))
    }

    static func pruebaLista(asignatura a: String, dia d: String) -> String {
        elegir(L3([("\(a) \(d): todo en luna llena. Vas a entrar como si fuera tu casa.",
                    "\(a) \(d): all full moons. You'll walk in like you own the place.",
                    "\(a) \(d): tutto in luna piena. Entri come se fossi a casa tua."),
                   ("Todas las lunas llenas. Si la profe pregunta, que pregunte.",
                    "Every moon is full. Let them ask.",
                    "Tutte le lune piene. Se la prof interroga, che interroghi.")]))
    }

    static func sinPruebas() -> String {
        elegir(L3([("No me has contado ninguna prueba. O no hay, o me ocultas algo.",
                    "You haven't told me about any tests. Either there are none, or you're hiding something.",
                    "Non mi hai detto nessuna verifica. O non ce ne sono, o mi nascondi qualcosa."),
                   ("Cero pruebas apuntadas. Sospechoso.",
                    "Zero tests logged. Suspicious.",
                    "Zero verifiche segnate. Sospetto."),
                   ("Si hay alguna prueba, hazle una foto al diario. Prometo no juzgar tu letra.",
                    "If there's a test, snap your planner. I promise not to judge your handwriting.",
                    "Se c'è una verifica, fai una foto al diario. Prometto di non giudicare la tua calligrafia.")]))
    }

    static func vuelta(dias: Int) -> String {
        elegir(L3([("Ah, hola. Pensaba que te habías mudado.",
                    "Oh, hi. I thought you'd moved.",
                    "Ah, ciao. Pensavo avessi traslocato."),
                   ("\(dias) días sin vernos. No pasa nada. Bueno, un poco sí.",
                    "\(dias) days without seeing each other. It's fine. Okay, a little not fine.",
                    "\(dias) giorni senza vederci. Niente. Cioè, un po' sì.")]))
    }

    static func mananaFalta(cosa c: String, asignatura a: String) -> String {
        let m = minusculaInicial(c)
        return elegir(L3([("\(c). Sin \(m) no hay \(a). Ni excusas.",
                           "\(c). No \(m), no \(a). No excuses.",
                           "\(c). Senza \(m) niente \(a). E niente scuse."),
                          ("\(c) sigue fuera de la mochila. Yo no puedo: no tengo manos.",
                           "\(c) is still outside the backpack. Can't help: no hands.",
                           "\(c) è ancora fuori dallo zaino. Io non posso: non ho le mani.")]))
    }

    static func mananaLista() -> String {
        elegir(L3([("Mochila lista. Hoy te dejo en paz. Un rato.",
                    "Backpack ready. I'll leave you alone today. For a bit.",
                    "Zaino pronto. Oggi ti lascio in pace. Per un po'."),
                   ("Todo dentro. Qué nivel.",
                    "Everything's in. What a pro.",
                    "Tutto dentro. Che livello.")]))
    }

    static func nocheMochila() -> String {
        elegir(L3([("La mochila no se hace sola. Lo he intentado: no tengo manos.",
                    "The backpack won't pack itself. I tried: no hands.",
                    "Lo zaino non si fa da solo. Ci ho provato: non ho le mani."),
                   ("Mañana hay clase. La mochila todavía no lo sabe.",
                    "School tomorrow. The backpack doesn't know yet.",
                    "Domani c'è scuola. Lo zaino non lo sa ancora.")]))
    }

    static func nocheLista() -> String {
        elegir(L3([("Mochila hecha. A dormir, que mañana te pregunto.",
                    "Backpack done. Off to bed, I'm quizzing you tomorrow.",
                    "Zaino fatto. A nanna, che domani ti interrogo."),
                   ("Todo listo. Ya puedes dormir: yo vigilo.",
                    "All set. Sleep, I'm on watch.",
                    "Tutto pronto. Puoi dormire, faccio la guardia io.")]))
    }

    static func preguntaNoche() -> String {
        elegir(L3([("Una pregunta y a dormir. Trato hecho.",
                    "One question and off to bed. Deal.",
                    "Una domanda e a nanna. Affare fatto."),
                   ("Última pregunta del día. Fácil. Creo.",
                    "Last question of the day. Easy. I think.",
                    "Ultima domanda della giornata. Facile. Credo.")]))
    }

    static func acierto(semilla: Int) -> String {
        elegir(L3([("Toma ya. ¿Seguro que no has mirado?", "Boom. Sure you didn't peek?", "Tiè. Sicuro che non hai sbirciato?"),
                   ("Eso es. Me estás dejando sin trabajo.", "Nailed it. You're putting me out of a job.",
                    "Esatto. Mi stai lasciando senza lavoro."),
                   ("Bien. Lo apunto antes de que se te olvide.", "Good. Writing it down before you forget.",
                    "Bene. Me lo segno prima che te lo scordi."),
                   ("Correcto. Ni yo lo habría dicho mejor. Bueno, sí.", "Correct. Couldn't have said it better. Okay, I could.",
                    "Giusto. Neanche io l'avrei detto meglio. Va be', sì.")]), semilla: semilla)
    }

    static func fallo(semilla: Int) -> String {
        elegir(L3([("Casi. Bueno, casi no. Te lo explico.", "Close. Well, not really. Let me explain.",
                    "Quasi. Cioè, quasi no. Te lo spiego."),
                   ("No pasa nada. A mí también me costó. Mentira, pero bueno.",
                    "No worries, it was hard for me too. Lie, but still.",
                    "Nessun problema, anche a me è costato. Bugia, ma vabbè."),
                   ("Fallo detectado. Fallo perdonado. Otra vez.", "Mistake spotted. Mistake forgiven. Again.",
                    "Errore rilevato. Errore perdonato. Di nuovo."),
                   ("Esa no. Pero para eso estoy.", "Not that one. That's what I'm here for.",
                    "Non è quella. Ma sono qui apposta.")]), semilla: semilla)
    }

    static func lunaLlena(tema t: String) -> String {
        elegir(L3([("AUUUU. \(t): luna llena.", "AWOOO. \(t): full moon.", "AUUUU. \(t): luna piena."),
                   ("AUUUU. \(t), al cielo. Una estrella más.", "AWOOO. \(t), up in the sky. One more star.",
                    "AUUUU. \(t), in cielo. Una stella in più.")]))
    }

    static func pruebaEntera(temas n: Int, dia d: String) -> String {
        let D = mayusculaInicial(d)
        return L(n == 1 ? "El tema, sabido. \(D) vas a entrar como si fuera tu casa."
                        : "Los \(n) temas, sabidos. \(D) vas a entrar como si fuera tu casa.",
                 n == 1 ? "The topic: nailed. \(D) you'll walk in like you own the place."
                        : "All \(n) topics: nailed. \(D) you'll walk in like you own the place.",
                 n == 1 ? "L'argomento è tuo. \(D) entri come se fossi a casa tua."
                        : "Tutti e \(n) gli argomenti, saputi. \(D) entri come se fossi a casa tua.")
    }

    static func fotoDiario() -> String {
        elegir(L3([("Tu letra es un reto. Pero lo he pillado.", "Your handwriting is a challenge. But I got it.",
                    "La tua calligrafia è una sfida. Ma l'ho capita."),
                   ("Leído. Tu letra y yo ya somos amigos.", "Read it. Your handwriting and I are friends now.",
                    "Letto. Io e la tua calligrafia ormai siamo amici.")]))
    }

    static func despuesPrueba() -> String {
        L("¿Qué tema te pilló por sorpresa? Venga, sin mentir.", "Which topic caught you off guard? Come on, no lying.",
          "Quale argomento ti ha preso alla sprovvista? Dai, senza mentire.")
    }

    static func temaDeAhora(asignatura a: String, tema t: String) -> String {
        elegir(L3([("En \(a) andan con ganas de preguntar. ¿\(t) qué tal?",
                    "They're in a quizzing mood in \(a). How's \(t)?",
                    "In \(a) hanno voglia di interrogare. \(t), come va?"),
                   ("\(t): por si te sacan sin avisar. Dos minutos y listo.",
                    "\(t): in case they call on you out of nowhere. Two minutes, done.",
                    "\(t): nel caso ti chiamino senza preavviso. Due minuti e via.")]))
    }

    static func avisoSinEstudiar(tema t: String) -> String {
        elegir(L3([("Vale, no estudies. Ya le explico yo a la profe lo de \(t).",
                    "Fine, don't study. I'll explain \(t) to your teacher myself.",
                    "Ok, non studiare. Con la prof per \(t) ci parlo io."),
                   ("\(t) y yo te echamos de menos. Bueno, sobre todo \(t).",
                    "\(t) and I miss you. Mostly \(t).",
                    "Io e \(t) ti aspettiamo. Soprattutto \(t).")]))
    }

    static func avisoRato(minutos m: Int) -> String {
        elegir(L3([("\(m) minutos. Lo que dura un capítulo de esa serie que ves.",
                    "\(m) minutes. One episode of that show you watch.",
                    "\(m) minuti. Quanto un episodio di quella serie che guardi."),
                   ("\(m) minutos de repaso y te dejo en paz. Palabra de lobo.",
                    "\(m) minutes of review and I'll leave you alone. Wolf's honor.",
                    "\(m) minuti di ripasso e ti lascio in pace. Parola di lupo.")]))
    }

    static func avisoLunes() -> String {
        L("Semana nueva. Las pruebas no se han ido de vacaciones.", "New week. The tests didn't go on vacation.",
          "Settimana nuova. Le verifiche non sono andate in vacanza.")
    }

    static func avisoPruebaManana(asignatura a: String) -> String {
        L("Mañana \(a). Diez minutos de repaso ligero y a dormir.", "\(a) tomorrow. Ten minutes of light review and off to bed.",
          "Domani \(a). Dieci minuti di ripasso leggero e a nanna.")
    }

    private static func L3(_ frases: [(String, String, String)]) -> [String] {
        frases.map { L($0.0, $0.1, $0.2) }
    }
}
