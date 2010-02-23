# some of this code is originally from the internet. (thanks)

cdef extern from "math.h":
    double log(double)
    double exp(double)

# Logarithm of n! with algorithmic approximation
# Reference:
#   Lanczos, C. 'A precision approximation of the gamma function',
#   J. SIAM Numer. Anal., B, 1, 86-96, 1964."
#   http://www.matforsk.no/ola/fisher.htm 
cdef inline double lnfactorial(int n):
    return 0 if n < 1 else lngamma(n + 1)


cdef inline double lngamma (int z):
    cdef double x = 0.1659470187408462e-06 / (z + 7)
    x += 0.9934937113930748e-05 / (z + 6)
    x -= 0.1385710331296526 / (z + 5)
    x += 12.50734324009056 / (z + 4)
    x -= 176.6150291498386 / (z + 3)
    x += 771.3234287757674 / (z + 2)
    x -= 1259.139216722289 / (z + 1)
    x += 676.5203681218835 / (z)
    x += 0.9999999999995183
    return log(x) - 5.58106146679532777 - z + (z - 0.5) * log(z + 6.5)

# Logarithm of the number of combinations of 'n' objects taken 'p' at a time
cdef inline double lncombination (int n, int p):
    return lnfactorial(n) - \
           lnfactorial(p) - \
           lnfactorial(n - p)


# Compute the hypergeometric probability, or probability that a list of
# 'n' objects should contain 'i' ones with a particular property when the
# list has been selected randomly without replacement from a set of 'G'
# objects in which 'C' exhibit the same property
cdef inline double hypergeometric_probability (int i, int n, int C, int G):
    return exp(
      lncombination(C, i) +
      lncombination(G - C, n - i) -
      lncombination(G, n)
     )


cdef inline int imin2(int a, int b):
    return a if a < b else b

cdef inline int imax2(int a, int b):
    return a if a > b else b

def pvalue_population(int k, int n, int C, int G):
    #print "k=%i, n=%i, C=%i, G=%i" % (k, n, C, G)
    return pvalue(k, n - k, C - k, G - C - n + k)

# k, n = study_true, study_tot, 
# C, G = population_true, population_tot
#def pvalue(int k, int n, int C, int G):
def pvalue(int a_true, int a_false, int b_true, int b_false):
    #print "a_true=%i, a_false=%i, b_true=%i, b_false=%i" % (a_true, a_false, b_true, b_false)

    # convert the a/b groups to study vs population.
    cdef int k = a_true
    cdef int n = a_false + a_true # total in study
    cdef int C = a_true + b_true
    cdef int G = C + a_false + b_false
    #print "k=%i, n=%i, C=%i, G=%i" % (k, n, C, G)

    cdef int um = imin2(n, C)
    cdef int lm = imax2(0, n + C - G)

    if um == lm:
        return 1.0, 1.0, 1.0

    cdef double cutoff = hypergeometric_probability(k, n, C, G)
    cdef double left_tail = 0, right_tail = 0, two_tailed = 0
    cdef int i
    cdef double p

    for i in range(lm, um + 1):
        p = hypergeometric_probability(i, n, C, G)

        if i <= k:
            left_tail += p

        if i >= k:
            right_tail += p

        if p <= cutoff:
            two_tailed += p

    left_tail = left_tail if left_tail < 1.0 else 1.0
    right_tail = right_tail if right_tail < 1.0 else 1.0
    two_tail = two_tail if two_tail < 1.0 else 1.0

    return (left_tail, right_tail, two_tailed)


def test():
    tablist = [
            ([[100, 2], [1000, 5]], (2.505583993422285e-001,  1.300759363430016e-001)),
            ([[2, 100], [5, 1000]], (2.505583993422285e-001,  1.300759363430016e-001)),
            ([[2, 7], [8, 2]], (8.586235135736206e-002,  2.301413756522114e-002)),
            ([[5, 1], [10, 10]], (4.725646047336584e+000,  1.973244147157190e-001)),
            ([[5, 15], [20, 20]], (3.394396617440852e-001,  9.580440012477637e-002)),
            ([[5, 16], [20, 25]], (3.960558326183334e-001,  1.725864953812994e-001)),
            ([[10, 5], [10, 1]], (2.116112781158483e-001,  1.973244147157190e-001)),
            ([[10, 5], [10, 0]], (0.000000000000000e+000,  6.126482213438734e-002)),
            ([[5, 0], [1, 4]], ('inf',  4.761904761904762e-002)),
            ([[0, 5], [1, 4]], (0.000000000000000e+000,  1.000000000000000e+000)),
            ([[5, 1], [0, 4]], ('inf',  4.761904761904758e-002)),
            ([[0, 1], [3, 2]], (0.000000000000000e+000,  1.000000000000000e+000))
            ]

    
    for table, ab in tablist:
        left, right, tt = pvalue(table[0][0], table[0][1], table[1][0], table[1][1])
        print table, tt
        assert abs(tt - ab[1]) < 0.1, (table, ab, left, right, tt)


def test_speed():
    cdef int i
    import time
    t = time.time()
    N = 100
    for i in range(N):
        left, right, tt = pvalue(1600, 40, 60, 21040)
    t = time.time() - t
    print "iterations/sec:", float(N)/t

