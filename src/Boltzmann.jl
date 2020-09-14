"""
    prefactor(pf)

returns prefactor of X_i, as given in
http://cococubed.asu.edu/code_pages/nse.shtml
"""
function prefactor(pf)
    (T, rho) -> (pf.A * pf.ω(T) *
                (2 * pf.s + 1) *
                (2.0 * T * π * Network_qse.k_B * pf.M * Network_qse.meverg /
                (Network_qse.c^2 * Network_qse.hh^2))^1.5
                /(rho * Network_qse.N_A))
end

"""
    initial_guess(ap_ni56)
index: 438 or 863 or 762
inverse of saha equation with only one species
and μₚ = μₙ. returns μ
"""
function initial_guess(ap_ni56; T = 2e9, rho = 1e7)
    scr2 = rho / (m_u * ap_ni56.A)
    λ3 = sqrt(2.0 * pi * k_B * T * ap_ni56.A * m_u / hh^2.0)^3.0
    mu = (kmev * T * log(scr2 / λ3) - 510.0) / ap_ni56.A
    return mu .* ones(2)
end



"""
    df_nse_condition!(J,μ, T,rho, ap)

computes Jacobian ∇f ∈ ℝ²×ℝ² with f ∈ ℝ², μ ∈ ℝ²
"""
function df_nse_condition(μ, T,rho, y, ap)
        sum_exp = zeros(Float64, 2)
        df11, df12, df21, df22 = zeros(Float64, 4)
        dres = zeros(Float64, 2, 2)

        for apᵢ in ap
            pr_i = prefactor(apᵢ)(T, rho)
            exp_i = exp((μ[1] * apᵢ.Z + μ[2] * (apᵢ.A -apᵢ.Z) - apᵢ.Eb) / (kmev * T)) .* BigFloat.([1.0, apᵢ.Z / apᵢ.A])
            sum_exp .= (prefactor(apᵢ)(T,rho) .* exp_i) .+ sum_exp
            df11 = prefactor(apᵢ)(T,rho) * exp_i[1] * apᵢ.Z / (kmev * T) + df11
            df12 = prefactor(apᵢ)(T,rho) * exp_i[1] * (apᵢ.A - apᵢ.Z) / (kmev * T) + df12
            df21 = prefactor(apᵢ)(T,rho) * exp_i[1] * apᵢ.Z * (apᵢ.Z / apᵢ.A) / (kmev * T) + df21
            df22 = prefactor(apᵢ)(T,rho) * exp_i[1] * (apᵢ.A - apᵢ.Z) * (apᵢ.Z / apᵢ.A) / (kmev * T) + df22
        end
        dres[1, 1] = df11 / sum_exp[1] #log (∑ᵢXᵢ)
        dres[1, 2] = df12 / sum_exp[1]
        dres[2, 1] = - df11 / sum_exp[1] * (sum_exp[2] / sum_exp[1]) + df21 / sum_exp[1]
        dres[2, 2] = - df12 / sum_exp[1] * (sum_exp[2] / sum_exp[1]) + df22 / sum_exp[1]
        return dres
end


"""
    nse_condition!(res, μ, T, ρ, y, ap; precision=400)
Mass conservation and charge neutrality
log (∑ᵢXᵢ) and log(∑ᵢ(Zᵢ/Aᵢ)Xᵢ / y)
"""
function nse_condition(μ, T::Real, ρ::Real, y::Real, ap; precision=4000)
        res = zeros(Real,2)
        scr = 0.0
        for (in, apᵢ) in enumerate(ap)
            pr_i = prefactor(apᵢ)(T, ρ)
            exp_i = exp((μ[1] * apᵢ.Z + μ[2] * (apᵢ.A -apᵢ.Z) - apᵢ.Eb) / (kmev*T))
            factor_i = [1.0, apᵢ.Z / apᵢ.A]
            res .= (pr_i .* factor_i .* exp_i) .+ res
        end
        res[2] = res[2] / res[1] - y
        res[1] = log(res[1])
        return res
end


function x_i(μ, T::Float64, ρ::Float64, a)
    map(apᵢ -> Network_qse.prefactor(apᵢ)(T, ρ) * exp((μ[1] * apᵢ.Z + μ[2] * (apᵢ.A - apᵢ.Z) - apᵢ.Eb) / (Network_qse.kmev*T)), a)
end
