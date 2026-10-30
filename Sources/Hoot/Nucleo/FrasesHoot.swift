import Foundation

enum FrasesHoot {

    static func elegir(_ opciones: [String], semilla: Int = hoy) -> String {
        opciones[((semilla % opciones.count) + opciones.count) % opciones.count]
    }

    static var hoy: Int { Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0 }

    static func mayusculaInicial(_ s: String) -> String { s.prefix(1).uppercased() + s.dropFirst() }

    static func enFrase(_ tema: String) -> String {
        let articulos: Set<String> = ["el", "la", "los", "las", "lo", "il", "i", "gli", "le", "the", "un", "una", "uno", "a", "an"]
        let primera = tema.split(separator: " ").first.map { $0.lowercased() } ?? ""
        if articulos.contains(primera) || tema.lowercased().hasPrefix("l'") { return minusculaInicial(tema) }
        return tema
    }
    static func minusculaInicial(_ s: String) -> String { s.prefix(1).lowercased() + s.dropFirst() }

    static func repasoPendiente(asignatura a: String, dia d: String, tema t: String, semilla: Int = hoy) -> String {
        elegir(L3([("\(a) \(d) y \(enFrase(t)) sigue en luna nueva. Yo solo lo digo.",
                    "\(a) \(d) and \(enFrase(t)) is still a new moon. Just saying.",
                    "\(a) \(d) e \(enFrase(t)) è ancora in luna nuova. Io lo dico e basta."),
                   ("\(mayusculaInicial(t)) lleva días esperándote. Las lunas no se llenan solas.",
                    "\(mayusculaInicial(t)) has been waiting for days. Moons don't fill themselves.",
                    "\(mayusculaInicial(t)) ti aspetta da giorni. Le lune non si riempiono da sole."),
                   ("\(a) \(d). \(mayusculaInicial(t)), sin tocar. Me pongo nervioso por ti.",
                    "\(a) \(d). \(mayusculaInicial(t)): untouched. I'm nervous for you.",
                    "\(a) \(d). \(mayusculaInicial(t)): zero ripassi. Mi agito io per te.")]), semilla: semilla)
    }

    static func repasoEnMarcha(tema t: String, semilla: Int = hoy) -> String {
        elegir(L3([("\(mayusculaInicial(t)) va por la mitad. Un empujón más y luna llena.",
                    "\(mayusculaInicial(t)) is halfway there. One more push and it's a full moon.",
                    "\(mayusculaInicial(t)) è a metà. Una spinta e luna piena."),
                   ("Media luna en \(enFrase(t)). La otra media no se va a estudiar sola.",
                    "Half a moon on \(enFrase(t)). The other half won't study itself.",
                    "Mezza luna su \(enFrase(t)). L'altra metà non si studia da sola."),
                   ("Vas bien con \(enFrase(t)). No te emociones, que mañana te pregunto.",
                    "Going well with \(enFrase(t)). Don't get cocky, I'm quizzing you tomorrow.",
                    "Su \(enFrase(t)) vai bene. Non montarti la testa, domani ti interrogo.")]), semilla: semilla)
    }

    static func pruebaLista(asignatura a: String, dia d: String, semilla: Int = hoy) -> String {
        elegir(L3([("\(a) \(d): todo en luna llena. Vas a entrar como si fuera tu casa.",
                    "\(a) \(d): all full moons. You'll walk in like you own the place.",
                    "\(a) \(d): tutto in luna piena. Entri come se fossi a casa tua."),
                   ("Todas las lunas llenas. Si la profe pregunta, que pregunte.",
                    "Every moon is full. Let them ask.",
                    "Tutte le lune piene. Se la prof interroga, che interroghi.")]), semilla: semilla)
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

    static func pruebaHoy(asignatura a: String, lista: Bool, tema t: String?) -> String {
        if lista || t == nil {
            return elegir(L3([("Hoy hay \(a). Respira: lo has preparado.", "\(a) today. Breathe: you're ready.", "Oggi c'è \(a). Respira: hai studiato."),
                              ("Hoy \(a). Todo en luna llena. Ve a por ella.", "\(a) today. All full moons. Go get it.",
                               "Oggi \(a). Tutto in luna piena. Vai e spacca.")]))
        }
        return L("Hoy hay \(a). Repasa \(t ?? "") en el recreo, que no muerde.", "\(a) today. Review \(t ?? "") at break, it doesn't bite.",
                 "Oggi c'è \(a). Ripassa \(t ?? "") all'intervallo, non morde.")
    }

    static func sinRepasoHoy() -> String {
        elegir(L3([("Hoy no toca repaso. Mañana sí: no te me escapes.", "No review today. Tomorrow, yes: don't run off.",
                    "Oggi niente ripasso. Domani sì: non scappare."),
                   ("Tarde sin repaso. Disfrútala, que no se repite mucho.", "An afternoon without review. Enjoy it, it won't happen often.",
                    "Pomeriggio senza ripasso. Goditelo, non capita spesso.")]))
    }

    static func agenda(pruebas n: Int, minutos m: Int) -> String {
        if n == 0 {
            return elegir(L3([("Semana tranquila. Sospechosamente tranquila.", "Quiet week. Suspiciously quiet.",
                               "Settimana tranquilla. Sospettosamente tranquilla."),
                              ("Ninguna prueba esta semana. Que no se entere nadie.", "No tests this week. Don't tell anyone.",
                               "Nessuna verifica questa settimana. Che non lo sappia nessuno.")]))
        }
        return elegir(L3([("Yo lo tengo todo controlado. Tú, ya veremos.", "I've got it all under control. You, we'll see.",
                           "Io ho tutto sotto controllo. Tu, vedremo."),
                          ("Las lunas no se llenan solas. Lo he comprobado.", "Moons don't fill themselves. I checked.",
                           "Le lune non si riempiono da sole. Ho controllato.")]))
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
        elegir(L3([("AUUUU. \(mayusculaInicial(t)): luna llena.", "AWOOO. \(mayusculaInicial(t)): full moon.", "AUUUU. \(mayusculaInicial(t)): luna piena."),
                   ("AUUUU. \(mayusculaInicial(t)), al cielo. Una estrella más.", "AWOOO. \(mayusculaInicial(t)), up in the sky. One more star.",
                    "AUUUU. \(mayusculaInicial(t)), in cielo. Una stella in più.")]))
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
        L("¿Qué tema te costó más en la prueba? Venga, sin mentir.", "Which topic was hardest in the test? Come on, no lying.",
          "Quale argomento ti è costato di più nella verifica? Dai, senza mentire.")
    }

    static func simulacro(semilla: Int = hoy) -> String {
        elegir(L3([("Ensayo general. Como el día de la prueba, pero sin nadie mirando.", "Dress rehearsal. Like test day, but nobody's watching.",
                    "Prova generale. Come il giorno della verifica, ma senza nessuno che guarda."),
                   ("Hoy hago de profe. Tranqui, yo no pongo notas.", "Today I'm the teacher. Relax, I don't give grades.",
                    "Oggi faccio il prof. Niente paura, io non metto voti."),
                   ("Lo que falles hoy, lo arreglamos mañana. Para eso está el ensayo.", "Whatever you miss today, we fix tomorrow. That's what rehearsals are for.",
                    "Quello che sbagli oggi lo sistemiamo domani. A questo serve la prova.")]), semilla: semilla)
    }

    static func simulacroCorregido(bien: Int, de total: Int) -> String {
        if total > 0 && bien == total {
            return L("Todo bien. El día de la prueba vas a entrar como si fuera tu casa.", "All correct. On test day you'll walk in like you own the place.",
                     "Tutto giusto. Il giorno della verifica entrerai come se fosse casa tua.")
        }
        if bien * 2 >= total {
            return L("Buen ensayo. Lo que falló ya está en el plan de mañana.", "Good rehearsal. What went wrong is already in tomorrow's plan.",
                     "Bella prova. Quello che non è andato è già nel piano di domani.")
        }
        return L("Para eso son los ensayos. Mañana repasamos lo rojo, que aún hay tiempo.", "That's what rehearsals are for. Tomorrow we go over the red bits; there's still time.",
                 "A questo servono le prove. Domani ripassiamo le cose in rosso, c'è ancora tempo.")
    }

    static func repasarFallado(_ n: Int) -> String {
        n == 1 ? L("Una pregunta se te resistió. Hoy no se escapa.", "One question got away. Not today.", "Una domanda ti ha resistito. Oggi non scappa.")
               : L("\(n) preguntas se te resistieron. Hoy no se escapa ninguna.", "\(n) questions got away. None escapes today.",
                   "\(n) domande ti hanno resistito. Oggi non ne scappa nessuna.")
    }

    static func temaDeAhora(asignatura a: String, tema t: String) -> String {
        elegir(L3([("En \(a) andan con ganas de preguntar. ¿\(mayusculaInicial(t)) qué tal?",
                    "They're in a quizzing mood in \(a). How's \(enFrase(t))?",
                    "In \(a) hanno voglia di interrogare. \(mayusculaInicial(t)), come va?"),
                   ("\(mayusculaInicial(t)): por si te sacan sin avisar. Dos minutos y listo.",
                    "\(mayusculaInicial(t)): in case they call on you out of nowhere. Two minutes, done.",
                    "\(mayusculaInicial(t)): nel caso ti chiamino senza preavviso. Due minuti e via.")]))
    }

    static func sinTemas() -> String {
        elegir(L3([("Apunta lo que estáis dando y yo me encargo de preguntarte. Con cariño, eso sí.",
                    "Add what you're covering and I'll handle the quizzing. Lovingly, of course.",
                    "Segna quello che state facendo e ti interrogo io. Con affetto, eh."),
                   ("Ni un tema apuntado. Así no hay quien aúlle.",
                    "Not a single topic. Nothing to howl about.",
                    "Neanche un argomento. Così non si ulula.")]))
    }

    static func temaParaSeguir(tema t: String) -> String {
        elegir(L3([("\(mayusculaInicial(t)) está a medias. Cinco minutos más y esa luna se pone redonda.",
                    "\(mayusculaInicial(t)) is halfway there. Five more minutes and that moon gets round.",
                    "\(mayusculaInicial(t)) è a metà. Cinque minuti e quella luna diventa tonda."),
                   ("¿Seguimos con \(enFrase(t))? Prometo no morder. Mucho.",
                    "Shall we keep going with \(enFrase(t))? I promise not to bite. Much.",
                    "Continuiamo con \(enFrase(t))? Prometto di non mordere. Troppo.")]))
    }

    static func todoLleno() -> String {
        elegir(L3([("Todas tus lunas llenas. Aúllo un rato y vuelvo.",
                    "All your moons are full. I'll howl for a bit and be right back.",
                    "Tutte le tue lune piene. Ululo un po' e torno."),
                   ("Ni una luna a medias. Apunta algo nuevo, que me aburro.",
                    "Not one half moon. Add something new, I'm bored.",
                    "Nessuna mezza luna. Segna qualcosa di nuovo, che mi annoio.")]))
    }

    static func avisoSinEstudiar(tema t: String) -> String {
        elegir(L3([("Vale, no estudies. Ya le explico yo a la profe lo de \(enFrase(t)).",
                    "Fine, don't study. I'll explain \(enFrase(t)) to your teacher myself.",
                    "Ok, non studiare. Con la prof per \(enFrase(t)) ci parlo io."),
                   ("\(mayusculaInicial(t)) y yo te echamos de menos. Bueno, sobre todo \(enFrase(t)).",
                    "\(mayusculaInicial(t)) and I miss you. Mostly \(enFrase(t)).",
                    "Io e \(enFrase(t)) ti aspettiamo. Soprattutto \(enFrase(t)).")]))
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
