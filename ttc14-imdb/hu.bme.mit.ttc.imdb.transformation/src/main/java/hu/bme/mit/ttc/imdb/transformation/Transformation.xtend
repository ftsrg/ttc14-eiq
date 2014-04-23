package hu.bme.mit.ttc.imdb.transformation

import hu.bme.mit.ttc.imdb.movies.Group
import hu.bme.mit.ttc.imdb.movies.Movie
import hu.bme.mit.ttc.imdb.movies.MoviesFactory
import hu.bme.mit.ttc.imdb.queries.CoupleWithRatingMatch
import hu.bme.mit.ttc.imdb.queries.Imdb
import java.util.Collection
import java.util.HashSet
import java.util.List
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.incquery.runtime.api.GenericPatternGroup
import org.eclipse.incquery.runtime.api.IQuerySpecification
import org.eclipse.incquery.runtime.api.IncQueryEngine
import com.google.common.math.DoubleMath

class Transformation {

	protected Resource r

	extension MoviesFactory = MoviesFactory.eINSTANCE
	extension Imdb = Imdb.instance

	def createCouples() {
		val x = new HashSet<IQuerySpecification<?>>
		x += #{personsToCouple, commonMoviesToCouple, personName}
		val group = new GenericPatternGroup(x)

		val engine = IncQueryEngine.on(r)
		group.prepare(engine);
		val coupleMatcher = engine.personsToCouple
		val commonMoviesMatcher = engine.commonMoviesToCouple
		val personNameMatcher = engine.personName

		coupleMatcher.forEachMatch [
			val couple = createCouple()
			val p1 = personNameMatcher.getAllValuesOfp(p1name).head
			val p2 = personNameMatcher.getAllValuesOfp(p2name).head
			couple.setP1(p1)
			couple.setP2(p2)
			val commonMovies = commonMoviesMatcher.getAllValuesOfm(p1name, p2name)
			couple.commonMovies.addAll(commonMovies)
			calculateAvgRating(commonMovies, couple)
			r.contents += couple
		]
	}

	def topCouplesByRating() {
		println("Top-15 by Average Rating")
		println("========================")
		val n = 15;
		val engine = IncQueryEngine.on(r)
		val coupleWithRatingMatcher = engine.coupleWithRating

		val ccfr = new CoupleComparatorForRating
		val rankedCouples = coupleWithRatingMatcher.allMatches.sort(ccfr)

		printCouples(n, rankedCouples)
	}

	def topCouplesByCommonMovies() {
		println("Top-15 by Number of Common Movies")
		println("=================================")

		val n = 15;
		val engine = IncQueryEngine.on(r)
		val coupleWithRatingMatcher = engine.coupleWithRating

		val ccfm = new CoupleComparatorForCommonMovies
		val rankedCouples = coupleWithRatingMatcher.allMatches.sort(ccfm)

		printCouples(n, rankedCouples)
	}

	def printCouples(int n, List<CoupleWithRatingMatch> rankedCouples) {
		(0 .. n - 1).forEach [
			val c = rankedCouples.get(it);
			println(
				String.format(
					"%d. Couple avgRating %.03f,  %d movies (%s; %s)",
					it + 1,
					c.avgRating,
					c.c.commonMovies.size,
					c.c.p1.name,
					c.c.p2.name
				))
		]
	}

	def calculateAvgRating(Collection<Movie> commonMovies, Group group) {
		var sumRating = 0.0

		for (m : commonMovies) {
			sumRating = sumRating + m.rating
		}
		val n = commonMovies.size
		group.avgRating = sumRating / n
		// group.avgRating = DoubleMath.mean(commonMovies.map[rating]) // if we have the latest version of Guava
	}

	def createCliques() {
		val engine = IncQueryEngine.on(r)
		val nextCliquesMatcher = getNextCliques(engine)
		val memberOfGroupMatcher = getMemberOfGroup(engine)
		val groupMatcher = getGroup(engine)

		val oldGroups = groupMatcher.allValuesOfg
		
		nextCliquesMatcher.forEachMatch [
			val clique = createClique()
			val gPersons = memberOfGroupMatcher.getAllValuesOfp(g)
			clique.commonMovies.addAll(g.commonMovies)
			clique.commonMovies.retainAll(p.movies)
			calculateAvgRating(clique.commonMovies, clique)
			clique.persons.addAll(gPersons)
			clique.persons.add(p)
			r.contents += clique
		]
		
		oldGroups.forEach[
			r.contents -= it
		]
	}
}